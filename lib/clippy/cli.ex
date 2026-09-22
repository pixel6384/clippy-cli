defmodule Clippy.CLI do
  @moduledoc ""

  def run do
    args = System.argv()
    case args do
      [] -> print_help()
      ["add", name | rest] -> add_snippet(name, Enum.join(rest, " "))
      ["get", name] -> get_snippet(name)
      ["list"] -> list_snippets()
      _ -> print_help()
    end
  end

  defp add_snippet(name, content) do
    storage_path = "~/.clippy/snippets"
    File.mkdir_p!(storage_path)
    File.write!(Path.join(storage_path, name), content)
    IO.puts("Saved snippet '#{name}'.")
  end

  defp get_snippet(name) do
    path = "~/.clippy/snippets/#{name}"
    if File.exists?(path) do
      content = File.read!(path)
      IO.puts(content)
    else
      IO.puts("Snippet '#{name}' not found.")
    end
  end

  defp list_snippets do
    path = "~/.clippy/snippets"
    if File.exists?(path) do
      File.ls!(path)
      |> Enum.each(&IO.puts/1)
    else
      IO.puts("No snippets saved yet.")
    end
  end

  defp print_help do
    IO.puts("Clippy - Clipboard Snippet Manager\n\n")
    IO.puts("Usage:")
    IO.puts("  clippy add <name> <content>  Save a snippet")
    IO.puts("  clippy get <name>           Retrieve a snippet")
    IO.puts("  clippy list                 List all snippets")
  end
end