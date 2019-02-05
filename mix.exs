defmodule LoggerDatadog.MixProject do
  use Mix.Project

  def project do
    [
      app: :logger_datadog,
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application, do: [extra_applications: [:logger, :inets]]

  defp paths(:test), do: ~w[lib/ test/support]
  defp paths(_), do: ~w[lib/]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.0"},

      # Testing
      {:stream_data, ">= 0.0.0", only: :test}
    ]
  end
end
