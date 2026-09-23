defmodule Clippy.CLI do
  @moduledoc ""

  def run do
    args = System.argv()
    case args do
      [] -> print_help()
      ["add", name | rest] -> add_snippet(name, Enum.join(rest, " "))
      ["append", name | rest] -> append_snippet(name, Enum.join(rest, " "))
      ["get", name] -> get_snippet(name)
      ["copy", name] -> copy_snippet(name)
      ["list"] -> list_snippets()
      ["rm", name] -> delete_snippet(name)
      ["clear"] -> clear_snippets()
      ["rename", old_name, new_name] -> rename_snippet(old_name, new_name)
      ["search", query] -> search_snippets(query)
      _ -> print_help()
    end
  end

  defp storage_dir do
    home = System.get_env("HOME") || System.get_env("USERPROFILE")
    Path.join(home, ".clippy", "snippets")
  end

  defp add_snippet(name, content) do
    storage_path = storage_dir()
    File.mkdir_p!(storage_path)
    File.write!(Path.join(storage_path, name), content)
    IO.puts("Saved snippet '#{name}'.")
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
      |> Enum.each(&IO.puts/1)
    else
      IO.puts("No snippets saved yet.")
    end
  end

  defp delete_snippet(name) do
    path = Path.join(storage_dir(), name)
    if File.exists?(path) do
      File.rm!(path)
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
      IO.puts("Renamed snippet '#{old_name}' to '#{new_name}'.")
    else
      IO.puts("Snippet '#{old_name}' not found.")
    end
  end

  defp search_snippets(query) do
    path = storage_dir()
    if File.exists?(path) do
      files = File.ls!(path)
      matches = 
        files
        |> Enum.filter(fn name ->
          content = File.read!(Path.join(path, name))
          String.contains?(content, query)
        end)

      if Enum.empty?(matches) do
        IO.puts("No snippets found containing '#{query}'.")
      else
        IO.puts("Found in snippets:")
        Enum.each(matches, &IO.puts(" - #{&1}"))
      end
    else
      IO.puts("No snippets saved yet.")
    end
  end

  defp print_help do
    IO.puts("Clippy - Clipboard Snippet Manager\n\n")
    IO.puts("Usage:")
    IO.puts("  clippy add <name> <content>    Save a snippet")
    IO.puts("  clippy append <name> <content>  Append to a snippet")
    IO.puts("  clippy get <name>              Retrieve a snippet")
    IO.puts("  clippy copy <name>             Copy snippet to clipboard")
    IO.puts("  clippy list                    List all snippets")
    IO.puts("  clippy rename <old> <new>      Rename a snippet")
    IO.puts("  clippy rm <name>               Remove a snippet")
    IO.puts("  clippy clear                    Remove all snippets")
    IO.puts("  clippy search <query>          Search snippets by content")
  end
end