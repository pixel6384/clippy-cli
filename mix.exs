defmodule Clippy.MixProject do
  use Mix.Project

  def project do
    [
      app: :clippy,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix. installations(),
      deps: []
    ]
  end

  def releases do
    [clippy: [application: :clippy]]
  end
end