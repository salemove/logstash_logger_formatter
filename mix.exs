defmodule LogstashLoggerFormatter.Mixfile do
  use Mix.Project

  def project do
    [
      app: :logstash_logger_formatter,
      version: "0.1.1",
      elixir: "~> 1.4",
      start_permanent: Mix.env() == :prod,
      build_embedded: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      docs: [
        extras: ["README.md"],
        main: "readme"
      ]
    ]
  end

  def description do
    ~S"""
    Logstash JSON formatter for Elixir standard Logger console backend
    """
  end

  def package do
    [
      maintainers: ["SaleMove TechMovers"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/salemove/logstash_logger_formatter"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:poison, "~> 1.0 or ~> 2.0 or ~> 3.0", optional: true},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
