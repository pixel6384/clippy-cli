defmodule Clippy.CLI do
  @moduledoc ""

  def run do
    args = System.argv()
    case args do
      [] -> print_help()
      ["add", name | rest] -> add_snippet(name, Enum.join(rest, " "))
      ["get", name] -> get_snippet(name)
      ["list"] -> list_snippets()
      ["rm", name] -> delete_snippet(name)
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

  defp get_snippet(name) do
    path = Path.join(storage_dir(), name)
    if File.exists?(path) do
      content = File.read!(path)
      IO.puts(content)
    else
      IO.puts("Snippet '#{name}' not found.")
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

  defp print_help do
    IO.puts("Clippy - Clipboard Snippet Manager\n\n")
    IO.puts("Usage:")
    IO.puts("  clippy add <name> <content>  Save a snippet")
    IO.puts("  clippy get <name>           Retrieve a snippet")
    IO.puts("  clippy list                 List all snippets")
    IO.puts("  clippy rm <name>            Remove a snippet")
  end
end