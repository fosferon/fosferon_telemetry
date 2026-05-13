defmodule FosferonTelemetry.MixProject do
  use Mix.Project

  def project do
    [
      app: :fosferon_telemetry,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "Shared failure-telemetry conventions for Fosferon Elixir apps. " <>
          "UTF-8-safe truncation, counter generation, and generic handler attachment.",
      package: package()
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
      {:ecto, "~> 3.12", only: :test, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/fosferon/fosferon_telemetry"}
    ]
  end
end
