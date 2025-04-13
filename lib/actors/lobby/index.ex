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
  def handle_cast({:success, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.success(msg))
    {:noreply, state}
  end

  # STOP
  @impl true
  def handle_cast({:stop}, %{name: n, behavior: lobby} = state) do
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
    IO.puts(data)

    case Actors.Lobby.Regex.check_game_opt_in(data) do
      {:ok, :opt_in} ->
        Actors.TableManager.add_player(player_actor, name)
        {:noreply, %{state | behavior: :opted_in}}

      {:error, :invalid_input} ->
        GenServer.cast(self(), {:warning, Actors.Lobby.Messages.invalid_input()})
        {:noreply, state}
    end
  end

  # STATE - REGISTERED
  @impl true
  def handle_cast({:recv, data, _}, %{name: name, behavior: :opted_in} = state) do
    case Actors.Lobby.Regex.check_game_opt_out(data) do
      {:ok, :opt_out} ->
        Actors.TableManager.remove_player(name)
        {:noreply, %{state | behavior: :lobby}}

      {:error, :invalid_input} ->
        GenServer.cast(self(), {:warning, Actors.Lobby.Messages.invalid_input()})
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:recv, _, _}, %{behavior: :opted_in} = state) do
    GenServer.cast(self(), {:warning, Messages.wait_for_game_start()})

    {:noreply, state}
  end

  # DEGUB that march everything
  def handle_cast({x, _}, state) do
    IO.inspect("Receiced " <> inspect(x) <> " behavior" <> inspect(state[:behavior]))

    {:noreply, state}
  end

  # - - -

  @impl true
  def init(%{client: client} = initial_state) do
    GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby()}"})

    {:ok, initial_state}
  end
end
