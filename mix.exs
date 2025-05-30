defmodule Elixir37noServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_37no_server,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    port = String.to_integer(System.get_env("PORT") || "4000")

    case Mix.env() do
      :test ->
        [extra_applications: [:logger, :ssl]]

      _ ->
        [
          extra_applications: [:logger, :ssl],
          mod: {SimpleServer, [port]}
        ]
    end
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:argon2_elixir, "~> 2.0"},
      {:bcrypt_elixir, "~> 3.3"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:decimal, "~> 2.3.0"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:table_rex, "~> 3.1"},
      {:ucwidth, "~> 0.1.0"},
      {:uuid, "~> 1.1"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
