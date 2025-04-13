defmodule Actors.Lobby do
  use GenServer

  defp init_state(client, bridge_actor, player_actor, name) do
    %{
      behavior: :lobby,
      client: client,
      name: name,
      bridge_actor: bridge_actor,
      player_actor: player_actor
    }
  end

  def start_link(client, bridge_actor, name) do
    IO.puts("Actor.Lobby start_link")

    {:ok, pid} = Actors.Player.start_link(client)

    GenServer.start_link(__MODULE__, init_state(client, bridge_actor, pid, name))
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

  @impl true
  def handle_cast({:success, head, msg}, %{client: client} = state) do
    :gen_tcp.send(client, "#{head}#{Messages.success(msg)}")
    {:noreply, state}
  end

  # STOP
  @impl true
  def handle_cast({:stop}, %{behavior: :lobby} = state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_cast({:stop}, %{name: name, behavior: :opted_in} = state) do
    Actors.TableManager.remove_player(name)
    {:stop, :normal, state}
  end

  # STATE - LOBBY
  @impl true
  def handle_cast({:recv, data, _}, %{name: name, player_actor: player_actor, behavior: :lobby} = state) do
    case Actors.Lobby.Regex.check_game_opt_in(data) do
      {:ok, :opt_in} ->
        case Actors.TableManager.add_player(player_actor, name) do
          {:error, :user_already_registered} ->
            GenServer.cast(self(), {:warning, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby()}\n\n", Actors.Lobby.Messages.user_already_opted_in(name)})
            {:noreply, state}

          {:ok, :user_opted_in} ->
            GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.opted_in()}\n\n"})
            {:noreply, %{state | behavior: :opted_in}}

          {:ok, :game_start} ->
            GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.opted_in()}\n\n"})
            {:noreply, %{state | behavior: :opted_in}}
        end

      {:error, :invalid_input} ->
        GenServer.cast(self(), {:warning, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby()}\n\n", Actors.Lobby.Messages.invalid_input_lobby(data)})
        {:noreply, state}
    end
  end

  # STATE - REGISTERED
  @impl true
  def handle_cast({:recv, data, _}, %{name: name, behavior: :opted_in} = state) do
    case Actors.Lobby.Regex.check_game_opt_out(data) do
      {:ok, :opt_out} ->
        case Actors.TableManager.remove_player(name) do
          # TODO: write a meaningfull error
          {:error, :user_not_registered} ->
            GenServer.cast(self(), {:warning, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.opted_in()}\n\n", "Generic error"})
            {:noreply, state}

          {:ok, msg} ->
            GenServer.cast(self(), {:success, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby()}\n\n", msg})
            {:noreply, %{state | behavior: :lobby}}
        end

      {:error, :invalid_input} ->
        GenServer.cast(self(), {:warning, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.opted_in()}\n\n", Actors.Lobby.Messages.invalid_input_opted_in(data)})
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:game_start}, %{behavior: :opted_in} = state) do
    {:noreply, %{state | behavior: :game_start}}
  end

  # STATE - GAME START
  @impl true
  def handle_cast({:recv, _, _} = envelop, %{player_actor: player_actor, behavior: :game_start} = state) do
    GenServer.cast(player_actor, envelop)
    # GenServer.cast(player_actor, Tuple.insert_at(envelop, tuple_size(envelop), self()))

    {:noreply, state}
  end

  # DEGUB that march everything
  def handle_cast({x, _}, state) do
    IO.inspect("Receiced " <> inspect(x) <> " behavior" <> inspect(state[:behavior]))

    {:noreply, state}
  end

  # - - -

  @impl true
  def init(initial_state) do
    GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby()}"})

    {:ok, initial_state}
  end
end
