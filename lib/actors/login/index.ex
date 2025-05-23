defmodule Actors.Login do
  @moduledoc """
  Actors.Login
  """
  alias Utils.Colors

  use GenServer

  defp init_state(bridge_pid) do
    %{
      behavior: :menu,
      client: nil,
      bridge_pid: bridge_pid
    }
  end

  def start(client, bridge_pid) do
    log("Actor.Login start [caller pid]" <> inspect(self()))

    GenServer.start(__MODULE__, %{init_state(bridge_pid) | client: client})
  end

  def start_link(client, bridge_pid) do
    log("Actor.Login start_link [caller pid]" <> inspect(self()))

    GenServer.start_link(__MODULE__, %{init_state(bridge_pid) | client: client})
  end

  # HANDLE INFO
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, {:shutdown, :bridge_shutdown_client_exit} = reason}, state) do
    log("Bridge #{inspect(pid)} exited with reason #{inspect(reason)}")

    {:stop, reason, state}
  end

  # PRINT MESSAGES
  @impl true
  def handle_cast({:message, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.message(msg))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:warning, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.warning(msg))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:warning, head, msg}, %{client: client} = state) do
    :gen_tcp.send(client, "#{head}#{Messages.warning(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:success, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.success(msg))
    {:noreply, state}
  end

  # STATE - MENU
  @impl true
  def handle_call({:recv, data}, _from, %{behavior: :menu} = state) do
    case Actors.Login.Regex.check_menu_input(data) do
      {:ok, :sign_in} ->
        GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Login.Messages.sign_in()}"})
        {:reply, {:ok, :goto_sign_in}, %{state | behavior: :sign_in}}

      {:ok, :sign_up} ->
        GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Login.Messages.sign_up()}"})
        {:reply, {:ok, :goto_sign_up}, %{state | behavior: :sign_up}}

      {:error, :invalid_input_back} ->
        GenServer.cast(
          self(),
          {:warning, "#{Messages.title()}\n\n#{Actors.Login.Messages.menu()}\n\n", "#{Actors.Login.Messages.menu_invalid_input_back(data)}"}
        )

        {:reply, {:error, :invalid_credentials}, state}

      {:error, :invalid_input} ->
        GenServer.cast(
          self(),
          {:warning, "#{Messages.title()}\n\n#{Actors.Login.Messages.menu()}\n\n", "#{Actors.Login.Messages.menu_invalid_input(data)}"}
        )

        {:reply, {:error, :invalid_credentials}, state}
    end
  end

  # STATE - SIGN IN
  @impl true
  def handle_call({:recv, data}, _from, %{behavior: :sign_in} = state) do
    case Actors.Login.Regex.check_username_and_password(data) do
      {:ok, :back} ->
        GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Login.Messages.menu()}"})
        {:reply, {:ok, :back}, %{state | behavior: :menu}}

      {:ok, name, password} ->
        case Actors.Persistence.Auth.authenticate(name, password) do
          {:ok, :authenticated} ->
            log("Login successful for user #{name}.")

            {:stop, :normal, {:ok, :goto_lobby, name}, state}

          {:error, :invalid_password} ->
            GenServer.cast(
              self(),
              {:warning, "#{Messages.title()}\n\n#{Actors.Login.Messages.sign_in()}\n\n", "#{Actors.Login.Messages.invalid_credentials(name, password)}"}
            )

            {:reply, {:error, :invalid_credentials}, state}

          {:error, :user_not_found} ->
            GenServer.cast(
              self(),
              {:warning, "#{Messages.title()}\n\n#{Actors.Login.Messages.sign_in()}\n\n", "#{Actors.Login.Messages.invalid_credentials(name, password)}"}
            )

            {:reply, {:error, :invalid_credentials}, state}
        end

      {:error, :invalid_input} ->
        GenServer.cast(
          self(),
          {:warning, "#{Messages.title()}\n\n#{Actors.Login.Messages.sign_in()}\n\n", "#{Actors.Login.Messages.sign_in_invalid_input(data)}"}
        )

        {:reply, {:error, :invalid_credentials}, state}
    end
  end

  # STATE - SIGN UP
  @impl true
  def handle_call({:recv, data}, _from, %{behavior: :sign_up} = state) do
    case Actors.Login.Regex.check_username_and_password(data) do
      {:ok, :back} ->
        GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Login.Messages.menu()}"})
        {:reply, {:ok, :back}, %{state | behavior: :menu}}

      {:ok, name, password} ->
        # Check the database
        case Actors.Persistence.Auth.register_user(name, password) do
          # Username is available, insert it
          :ok ->
            Actors.Persistence.Stats.init_player(name)

            log("User #{name} signed up successfully.")

            {:stop, :normal, {:ok, :goto_lobby, name}, state}

          # Username already exists
          {:error, :user_already_exists} ->
            GenServer.cast(
              self(),
              {:warning, "#{Messages.title()}\n\n#{Actors.Login.Messages.sign_up()}\n\n", Actors.Login.Messages.username_already_exist(name)}
            )

            {:reply, {:error, :invalid_credentials}, state}
        end

      {:error, :invalid_input} ->
        GenServer.cast(
          self(),
          {:warning, "#{Messages.title()}\n\n#{Actors.Login.Messages.sign_up()}\n\n", "#{Actors.Login.Messages.sign_up_invalid_input(data)}"}
        )

        {:reply, {:error, :invalid_credentials}, state}
    end
  end

  # DEGUB that march everything
  @impl true
  def handle_cast({x, _}, state) do
    log("Receiced " <> inspect(x) <> " behavior" <> inspect(state[:behavior]))

    {:noreply, state}
  end

  # - - -

  @impl true
  def init(%{bridge_pid: bridge_pid} = initial_state) do
    log("Actor.Login init" <> inspect(self()))

    Process.monitor(bridge_pid)

    GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Login.Messages.menu()}"})

    {:ok, initial_state}
  end

  defp log(msg) do
    IO.puts("#{Colors.with_light_cyan("Login")} #{msg}")
  end
end
