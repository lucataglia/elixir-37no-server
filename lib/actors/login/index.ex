defmodule Actors.Login do
  @moduledoc """
  Actors.Login
  """

  use GenServer

  defp init_state() do
    %{
      behavior: :menu,
      client: nil,
      parent_pid: nil
    }
  end

  def start_link(client, parent_pid) do
    IO.puts("Actor.Login start_link [caller pid]" <> inspect(self()))

    GenServer.start_link(__MODULE__, %{init_state() | client: client, parent_pid: parent_pid})
  end

  # Handle :DOWN message when the parent dies
  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    IO.puts("Parent process stopped with reason: #{inspect(reason)}")
    # Perform cleanup or other actions before stopping

    {:stop, :normal, state}
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
        case :ets.lookup(:users, name) do
          [{^name, ^password}] ->
            IO.puts("Login successful for user #{name}.")

            {:stop, :normal, {:ok, :goto_lobby, name}, state}

          [{^name, _}] ->
            GenServer.cast(
              self(),
              {:warning, "#{Messages.title()}\n\n#{Actors.Login.Messages.sign_in()}\n\n", "#{Actors.Login.Messages.invalid_credentials(name, password)}"}
            )

            {:reply, {:error, :invalid_credentials}, state}

          [] ->
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
        case :ets.lookup(:users, name) do
          # Username is available, insert it
          [] ->
            # TODO: hashing the password before writing
            :ets.insert(:users, {name, password})

            IO.puts("User #{name} signed up successfully.")

            {:stop, :normal, {:ok, :goto_lobby, name}, state}

          # Username already exists
          _ ->
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
  def handle_cast({x, _}, state) do
    IO.puts("Receiced " <> inspect(x) <> " behavior" <> inspect(state[:behavior]))

    {:noreply, state}
  end

  # - - -

  @impl true
  def init(%{parent_pid: parent_pid} = initial_state) do
    IO.puts("Actor.Login init" <> inspect(self()))
    IO.puts("Actor.Login monitor" <> inspect(parent_pid))

    Process.monitor(parent_pid)

    GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Login.Messages.menu()}"})

    {:ok, initial_state}
  end
end
