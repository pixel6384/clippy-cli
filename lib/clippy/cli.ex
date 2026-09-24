defmodule Clippy.CLI do
  @moduledoc ""

  def run do
    args = System.argv()
    case args do
      [] -> print_help()
      ["add", name | rest] -> add_snippet(name, rest)
      ["set", name | rest] -> set_snippet(name, rest)
      ["append", name | rest] -> append_snippet(name, Enum.join(rest, " "))
      ["get", name] -> get_snippet(name)
      ["cat", name] -> get_snippet(name)
      ["copy", name] -> copy_snippet(name)
      ["list"] -> list_snippets()
      ["rm", name] -> delete_snippet(name)
      ["clear"] -> clear_snippets()
      ["rename", old_name, new_name] -> rename_snippet(old_name, new_name)
      ["search", query] -> search_snippets(query)
      ["import", dir] -> import_snippets(dir)
      ["export", name, file] -> export_snippet(name, file)
      ["stats"] -> show_stats()
      ["tag", name, tag] -> tag_snippet(name, tag)
      ["untag", name, tag] -> untag_snippet(name, tag)
      ["tags"] -> list_all_tags()
      _ -> print_help()
    end
  end

  defp storage_dir do
    home = System.get_env("HOME") || System.get_env("USERPROFILE")
    Path.join(home, ".clippy", "snippets")
  end

  defp tags_file do
    Path.join(storage_dir(), ".tags")
  end

  defp resolve_content(rest) do
    case rest do
      [] -> nil
      [path] when File.exists?(path) -> File.read!(path)
      rest -> Enum.join(rest, " ")
    end
  end

  defp add_snippet(name, rest) do
    content = resolve_content(rest)
    if is_nil(content) do
      IO.puts("Error: No content provided for snippet '#{name}'. Provide text or a path to a file.")
    else
      storage_path = storage_dir()
      File.mkdir_p!(storage_path)
      path = Path.join(storage_path, name)

      if File.exists?(path) do
        IO.puts("Snippet '#{name}' already exists. Use 'set' to update it or 'rm' to delete it first.")
      else
        File.write!(path, content)
        IO.puts("Saved snippet '#{name}'.")
      end
    end
  end

  defp set_snippet(name, rest) do
    content = resolve_content(rest)
    if is_nil(content) do
      IO.puts("Error: No content provided for snippet '#{name}'. Provide text or a path to a file.")
    else
      path = Path.join(storage_dir(), name)
      if File.exists?(path) do
        File.write!(path, content)
        IO.puts("Updated snippet '#{name}'.")
      else
        IO.puts("Snippet '#{name}' not found. Use 'add' to create it first.")
      end
    end
  end

  defp append_snippet(name, content) do
    path = Path.join(storage_dir(), name)
    if File.exists?(path) do
      File.write!(path, "\n" <> content, [:append])
      IO.puts("Appended to snippet '#{name}'.")
    else
      IO.puts("Snippet '#{name}' not found. Use 'add' to create it first.")
    end
  end

  defp get_snippet(name) do
    path = Path.join(storage_dir(), name)
    if File.exists?(path) do
      content = File.read!(path)
      IO.puts(content)
    else
      IO.puts("Snippet '#{name}' not found.")
    end
  end

  defp copy_snippet(name) do
    path = Path.join(storage_dir(), name)
    if File.exists?(path) do
      content = File.read!(path)
      case get_clipboard_command() do
        {cmd, args} ->
          System.cmd(cmd, args, input: content)
          IO.puts("Snippet '#{name}' copied to clipboard.")
        nil ->
          IO.puts("No system clipboard tool found (pbcopy, xclip, or clip).")
      end
    else
      IO.puts("Snippet '#{name}' not found.")
    end
  end

  defp get_clipboard_command do
    # Basic OS detection for clipboard tools
    os = :os.type()
    cond do
      os == :darwin -> {"pbcopy", []}
      os == :linux -> {"xclip", ["-selection", "clipboard"]}
      os == :nt -> {"clip", []}
      true -> nil
    end
  end

  defp list_snippets do
    path = storage_dir()
    if File.exists?(path) do
      File.ls!(path)
      |> Enum.reject(fn f -> f == ".tags" end)
      |> Enum.each(&IO.puts/1)
    else
      IO.puts("No snippets saved yet.")
    end
  end

  defp delete_snippet(name) do
    path = Path.join(storage_dir(), name)
    if File.exists?(path) do
      File.rm!(path)
      remove_tags_for(name)
      IO.puts("Deleted snippet '#{name}'.")
    else
      IO.puts("Snippet '#{name}' not found.")
    end
  end

  defp clear_snippets do
    path = storage_dir()
    if File.exists?(path) do
      files = File.ls!(path)
      Enum.each(files, fn file ->
        File.rm!(Path.join(path, file))
      end)
      IO.puts("All snippets cleared.")
    else
      IO.puts("No snippets to clear.")
    end
  end

  defp rename_snippet(old_name, new_name) do
    old_path = Path.join(storage_dir(), old_name)
    new_path = Path.join(storage_dir(), new_name)

    if File.exists?(old_path) do
      File.mv!(old_path, new_path)
      rename_tags(old_name, new_name)
      IO.puts("Renamed snippet '#{old_name}' to '#{new_name}'.")
    else
      IO.puts("Snippet '#{old_name}' not found.")
    end
  end

  defp search_snippets(query) do
    path = storage_dir()
    if File.exists?(path) do
      # Check if query is a tag (starts with #)
      if String.starts_with?(query, "#") do
        tag = String.slice(query, 1..-1)
        matches = get_snippets_by_tag(tag)
        print_matches(matches, query)
      else
        files = File.ls!(path) |> Enum.reject(fn f -> f == ".tags" end)
        matches = 
          files
          |> Enum.filter(fn name ->
            content = File.read!(Path.join(path, name))
            String.contains?(name, query) or String.contains?(content, query)
          end)
        print_matches(matches, query)
      end
    else
      IO.puts("No snippets saved yet.")
    end
  end

  defp print_matches(matches, query) do
    if Enum.empty?(matches) do
      IO.puts("No snippets found matching '#{query}'.")
    else
      IO.puts("Found matches in:")
      Enum.each(matches, &IO.puts(" - #{&1}"))
    end
  end

  defp import_snippets(dir) do
    if File.dir?(dir) do
      storage_path = storage_dir()
      File.mkdir_p!(storage_path)
      
      files = 
        File.ls!(dir)
        |> Enum.filter(fn file -> not String.starts_with?(file, ".") end)

      Enum.each(files, fn file ->
        content = File.read!(Path.join(dir, file))
        File.write!(Path.join(storage_path, file), content)
      end)
      IO.puts("Imported #{length(files)} snippets from #{dir}.")
    else
      IO.puts("Error: '#{dir}' is not a valid directory.")
    end
  end

  defp export_snippet(name, destination) do
    path = Path.join(storage_dir(), name)
    if File.exists?(path) do
      content = File.read!(path)
      File.write!(destination, content)
      IO.puts("Exported snippet '#{name}' to #{destination}.")
    else
      IO.puts("Snippet '#{name}' not found.")
    end
  end

  defp show_stats do
    path = storage_dir()
    if File.exists?(path) do
      files = File.ls!(path) |> Enum.reject(fn f -> f == ".tags" end)
      count = length(files)
      total_size = 
        files
        |> Enum.reduce(0, fn file, acc ->
          File.read!(Path.join(path, file)) |> String.length() |> Kernel.+(acc)
        end)

      IO.puts("Clippy Library Stats:")
      IO.puts("  Total Snippets: #{count}")
      IO.puts("  Total Characters: #{total_size}")
    else
      IO.puts("No snippets saved yet.")
    end
  end

  defp tag_snippet(name, tag) do
    path = Path.join(storage_dir(), name)
    if File.exists?(path) do
      add_tag(name, tag)
      IO.puts("Added tag '#{tag}' to snippet '#{name}'.")
    else
      IO.puts("Snippet '#{name}' not found.")
    end
  end

  defp untag_snippet(name, tag) do
    path = Path.join(storage_dir(), name)
    if File.exists?(path) do
      remove_tag(name, tag)
      IO.puts("Removed tag '#{tag}' from snippet '#{name}'.")
    else
      IO.puts("Snippet '#{name}' not found.")
    end
  end

  defp list_all_tags do
    tags = load_tags()
    if Map.empty?(tags) do
      IO.puts("No tags found.")
    else
      # Invert the map: from {snippet => [tags]} to {tag => [snippets]}
      inverted_tags = 
        tags
        |> Enum.flat_map(fn {name, t_list} -> Enum.map(t_list, fn t -> {t, name} end) end)
        |> Enum.group_by(fn {t, _name} -> t end, fn {_t, name} -> name end)

      IO.puts("Existing Tags:")
      Enum.each(inverted_tags, fn {tag, snippets} ->
        IO.puts("  #{tag}: #{Enum.join(snippets, ", ")}")
      end)
    end
  end

  defp add_tag(name, tag) do
    tags = load_tags()
    current_tags = Map.get(tags, name, [])
    updated_tags = if tag in current_tags, do: current_tags, else: [tag | current_tags]
    save_tags(Map.put(tags, name, updated_tags))
  end

  defp remove_tag(name, tag) do
    tags = load_tags()
    case Map.get(tags, name) do
      nil -> :ok
      t_list ->
        updated_tags = Enum.reject(t_list, fn t -> t == tag end)
        save_tags(Map.put(tags, name, updated_tags))
    end
  end

  defp get_snippets_by_tag(tag) do
    tags = load_tags()
    tags
    |> Enum.filter(fn {_name, t_list} -> tag in t_list end)
    |> Enum.map(fn {name, _t_list} -> name end)
  end

  defp remove_tags_for(name) do
    tags = load_tags()
    save_tags(Map.delete(tags, name))
  end

  defp rename_tags(old_name, new_name) do
    tags = load_tags()
    case Map.get(tags, old_name) do
      nil -> :ok
      t_list -> 
        tags
        |> Map.delete(old_name)
        |> Map.put(new_name, t_list)
        |> save_tags()
    end
  end

  defp load_tags do
    file = tags_file()
    if File.exists?(file) do
      case :erlang.term_to_binary(File.read!(file)) rescue _ -> {} end
      # Using simple term storage for internal metadata
      # In a real app, we'd use JSON, but for this CLI, Erlang term is concise
      # Actually, let's use simple text parsing for safety if we don't have JSON
      # but since it's internal, let's just use a simple map string representation
      # For simplicity in this implementation, we use a basic format: "name:tag1,tag2\n"
      File.read!(file)
      |> String.split("\n", trim: true)
      |> Enum.reduce(%{}, fn line, acc ->
        [name, tags_str] = String.split(line, ":", parts: 2)
        Map.put(acc, name, String.split(tags_str, ","))
      end)
    else
      %{}
    end
  end

  defp save_tags(tags) do
    content = 
      tags
      |> Enum.map(fn {name, t_list} -> "#{name}:#{Enum.join(t_list, ",")}" end)
      |> Enum.join("\n")
    File.write!(tags_file(), content)
  end

  defp print_help do
    IO.puts("Clippy - Clipboard Snippet Manager\n\n")
    IO.puts("Usage:")
    IO.puts("  clippy add <name> <content|file> Save a snippet (supports file path as content)")
    IO.puts("  clippy set <name> <content|file> Update a snippet (supports file path as content)")
    IO.puts("  clippy append <name> <content>  Append to a snippet")
    IO.puts("  clippy get/cat <name>           Retrieve a snippet")
    IO.puts("  clippy copy <name>             Copy snippet to clipboard")
    IO.puts("  clippy list                    List all snippets")
    IO.puts("  clippy rename <old> <new>      Rename a snippet")
    IO.puts("  clippy rm <name>               Remove a snippet")
    IO.puts("  clippy clear                    Remove all snippets")
    IO.puts("  clippy search <query>          Search snippets by name or content (use #tag to search by tag)")
    IO.puts("  clippy import <dir>            Import snippets from directory")
    IO.puts("  clippy export <name> <file>    Export snippet to file")
    IO.puts("  clippy stats                    Show library statistics")
    IO.puts("  clippy tag <name> <tag>         Add a tag to a snippet")
    IO.puts("  clippy untag <name> <tag>       Remove a tag from a snippet")
    IO.puts("  clippy tags                     List all tags and their snippets")
  end
end