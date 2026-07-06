defmodule FosferonTelemetry.MixProject do
  use Mix.Project

  @source_url "https://github.com/fosferon/fosferon_telemetry"
  @version "0.1.0"

  def project do
    [
      app: :fosferon_telemetry,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "Shared failure-telemetry conventions for Elixir apps. " <>
          "UTF-8-safe truncation, counter generation, and generic handler attachment.",
      package: package(),
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:telemetry, "~> 1.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:postgrex, "~> 0.19", only: :test, runtime: false},
      {:ecto, "~> 3.12", only: :test, runtime: false},
      {:ex_doc, "~> 0.36", only: :dev, runtime: false},
      {:earmark, "~> 1.4", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "LICENSE"],
      groups_for_modules: [
        "Shaping": [FosferonTelemetry.Util],
        "Metrics": [FosferonTelemetry.FailureMetrics],
        "Handlers": [FosferonTelemetry.FailureHandler]
      ]
    ]
  end
end
