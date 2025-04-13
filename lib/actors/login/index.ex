defmodule Actors.Login do
  use GenServer

  defp init_state(client) do
    %{
      behavior: :menu,
      client: client
    }
  end

  def start_link(client) do
    IO.puts("Actor.Login start_link [caller pid]" <> inspect(self()))

    GenServer.start_link(__MODULE__, init_state(client))
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

  # STOP
  @impl true
  def handle_cast({:stop}, %{name: n} = state) do
    Actors.TableManager.player_stop(n)
    {:stop, :normal, state}
  end

  # STATE - MENU
  @impl true
  def handle_cast({:recv, data, _}, %{behavior: :menu} = state) do
    case Actors.Login.Regex.check_menu_input(data) do
      {:ok, :sign_in} ->
        GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Login.Messages.sign_in()}"})
        {:noreply, %{state | behavior: :sign_in}}

      {:ok, :sign_up} ->
        GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Login.Messages.sign_up()}"})
        {:noreply, %{state | behavior: :sign_up}}

      {:error, :invalid_input} ->
        GenServer.cast(
          self(),
          {:warning, "#{Messages.title()}\n\n#{Actors.Login.Messages.menu()}\n\n", "#{Actors.Login.Messages.menu_invalid_input(data)}"}
        )

        {:noreply, state}
    end
  end

  # STATE - SIGN IN
  @impl true
  def handle_cast({:recv, data, bridge_actor}, %{behavior: :sign_in} = state) do
    case Actors.Login.Regex.check_username_and_password(data) do
      {:ok, :back} ->
        GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Login.Messages.menu()}"})
        {:noreply, %{state | behavior: :menu}}

      {:ok, name, password} ->
        case :ets.lookup(:users, name) do
          [{^name, ^password}] ->
            IO.puts("Login successful for user #{name}.")

            GenServer.cast(bridge_actor, {:goto_lobby, name})
            {:stop, :normal, state}

          [{^name, _}] ->
            GenServer.cast(
              self(),
              {:warning, "#{Messages.title()}\n\n#{Actors.Login.Messages.sign_in()}\n\n", "#{Actors.Login.Messages.invalid_credentials(name, password)}"}
            )

            {:noreply, state}

          [] ->
            GenServer.cast(
              self(),
              {:warning, "#{Messages.title()}\n\n#{Actors.Login.Messages.sign_in()}\n\n", "#{Actors.Login.Messages.invalid_credentials(name, password)}"}
            )

            {:noreply, state}
        end

      {:error, :invalid_input} ->
        GenServer.cast(
          self(),
          {:warning, "#{Messages.title()}\n\n#{Actors.Login.Messages.sign_in()}\n\n", "#{Actors.Login.Messages.sign_in_invalid_input(data)}"}
        )

        {:noreply, state}
    end
  end

  # STATE - SIGN UP
  @impl true
  def handle_cast({:recv, data, bridge_actor}, %{behavior: :sign_up} = state) do
    case Actors.Login.Regex.check_username_and_password(data) do
      {:ok, :back} ->
        GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Login.Messages.menu()}"})
        {:noreply, %{state | behavior: :menu}}

      {:ok, name, password} ->
        # Check the database
        case :ets.lookup(:users, name) do
          # Username is available, insert it
          [] ->
            # TODO: hashing the password before writing 
            :ets.insert(:users, {name, password})

            IO.puts("User #{name} signed up successfully.")
            GenServer.cast(bridge_actor, {:goto_lobby, name})
            {:stop, :normal, state}

          # Username already exists
          _ ->
            GenServer.cast(
              self(),
              {:warning, "#{Messages.title()}\n\n#{Actors.Login.Messages.sign_up()}\n\n", Actors.Login.Messages.username_already_exist(name)}
            )

            {:noreply, state}
        end

      {:error, :invalid_input} ->
        GenServer.cast(
          self(),
          {:warning, "#{Messages.title()}\n\n#{Actors.Login.Messages.sign_up()}\n\n", "#{Actors.Login.Messages.sign_up_invalid_input(data)}"}
        )

        {:noreply, state}
    end
  end

  # DEGUB that march everything
  def handle_cast({x, _}, state) do
    IO.inspect("Receiced " <> inspect(x) <> " behavior" <> inspect(state[:behavior]))

    {:noreply, state}
  end

  # - - -

  @impl true
  def init(initial_state) do
    IO.puts("Actor.Login init" <> inspect(self()))

    GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Login.Messages.menu()}"})

    {:ok, initial_state}
  end
end
