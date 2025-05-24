defmodule Utils.Log do
  @moduledoc """
  MyLogger
  """
  # Logs a message with a name and color function
  def log(actor, msg, color_fun) when is_function(color_fun, 1) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")

    [{_module, _function, _arity, location} | _] =
      Process.info(self(), :current_stacktrace)
      |> elem(1)
      |> Enum.drop(2)

    file = Keyword.get(location, :file, "unknown") |> Path.basename()
    line = Keyword.get(location, :line, 0)

    IO.puts("#{timestamp} #{color_fun.(actor)} [#{file}:#{line}] \t #{msg}")
  end

  def log(actor, n, msg, color_fun) when is_function(color_fun, 1) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")

    [{_module, _function, _arity, location} | _] =
      Process.info(self(), :current_stacktrace)
      |> elem(1)
      |> Enum.drop(2)

    file = Keyword.get(location, :file, "unknown") |> Path.basename()
    line = Keyword.get(location, :line, 0)

    IO.puts("#{timestamp} #{color_fun.(actor)} #{Utils.Colors.with_underline(n)} [#{file}:#{line}] \t #{msg}")
  end

  # Logs a debug message with a name and color function
  def log_debug(actor, n, msg) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")

    [{_module, _function, _arity, location} | _] =
      Process.info(self(), :current_stacktrace)
      |> elem(1)
      |> Enum.drop(2)

    file = Keyword.get(location, :file, "unknown") |> Path.basename()
    line = Keyword.get(location, :line, 0)

    log_line = "#{timestamp} #{actor} (DEBUG) #{n} [#{file}:#{line}]: \t #{msg}"
    IO.puts(Utils.Colors.with_red_bright(log_line))
  end
end
