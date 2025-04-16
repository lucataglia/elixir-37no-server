defmodule Actors.Lobby do
  @moduledoc """
  Actors.Lobby
  """
  alias Utils.Colors

  use GenServer

  defp init_state(client, name, parent_pid) do
    %{
      behavior: :lobby,
      client: client,
      name: name,
      parent_pid: parent_pid,
      player_actor: nil
    }
  end

  def start_link(client, name, parent_pid) do
    IO.puts("Actor.Lobby start_link " <> inspect(self()))

    GenServer.start_link(__MODULE__, init_state(client, name, parent_pid))
  end

  # Handle :DOWN message when the parent dies
  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, %{name: name, behavior: :opted_in} = state) do
    IO.puts("Parent process stopped with reason: #{inspect(reason)}")

    # Perform cleanup or other actions before stopping
    case Actors.GameManager.remove_player(name) do
      {:ok, _} ->
        {:stop, :normal, state}

      {:error} ->
        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    IO.puts("Parent process stopped with reason: #{inspect(reason)}")

    {:stop, :normal, state}
  end

  # PRINT MESSAGES
  @impl true
  def handle_cast({:message, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.message(msg))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:message, head, msg}, %{client: client} = state) do
    :gen_tcp.send(client, "#{head}#{Messages.message(msg)}")
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

  # STATE - LOBBY
  @impl true
  def handle_cast({:recv, data}, %{name: name, player_actor: player_actor, behavior: :lobby} = state) do
    case Actors.Lobby.Regex.check_game_opt_in(data) do
      {:ok, :opt_in} ->
        case Actors.GameManager.add_player(name, player_actor) do
          {:error, :user_already_registered} ->
            GenServer.cast(self(), {:warning, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby()}\n\n", Actors.Lobby.Messages.user_already_opted_in(name)})
            {:noreply, state}

          {:ok, :user_opted_in, msg} ->
            GenServer.cast(self(), {:success, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.opted_in()}\n\n", msg})
            {:noreply, %{state | behavior: :opted_in}}

          {:ok, :game_start} ->
            {:noreply, %{state | behavior: :opted_in}}
        end

      {:ok, :list_my_open_tables} ->
        case Actors.GameManager.list_open_tables(name) do
          {:ok, :no_active_game} ->
            GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby()}\n\n", "You have zero game in progess"})
            {:noreply, state}

          {:ok, list} ->
            msg = Enum.map(list, fn {game_uuid, game_desc} -> "#{Colors.with_underline("rejoin #{game_uuid}")} - #{game_desc}" end)
            GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby()}\n\n", msg})
            {:noreply, state}
        end

      {:ok, :list_all_open_tables} ->
        case Actors.GameManager.list_all_open_tables() do
          {:ok, list} when list == [] ->
            GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby()}\n\n", "There are zero games in progess"})

            {:noreply, state}

          {:ok, list} ->
            msg = Enum.map(list, fn {game_uuid, game_desc} -> "#{Colors.with_underline("observe #{game_uuid}")} - #{game_desc}" end)
            GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby()}\n\n", msg})
            {:noreply, state}
        end

      {:ok, :rejoin, uuid} ->
        case Actors.GameManager.rejoin(name, uuid, player_actor) do
          {:ok, :table_manager_informed} ->
            warn_msg = {:warning, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby()}\n\n", "Please wait..."}
            GenServer.cast(self(), warn_msg)

            {:noreply, state}

          {:error, :game_does_not_exist} ->
            warn_msg = {:warning, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby()}\n\n", "Game #{Colors.with_underline(uuid)} does not exist. It may have been terminated."}
            GenServer.cast(self(), warn_msg)

            {:noreply, state}
        end

      {:ok, :observe, uuid} ->
        case Actors.GameManager.observe(name, uuid, player_actor) do
          {:ok, :table_manager_informed} ->
            warn_msg = {:warning, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby()}\n\n", "Please wait..."}
            GenServer.cast(self(), warn_msg)

            {:noreply, state}

          {:error, :game_does_not_exist} ->
            warn_msg = {:warning, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby()}\n\n", "Game #{Colors.with_underline(uuid)} does not exist. It may have been terminated."}
            GenServer.cast(self(), warn_msg)

            {:noreply, state}
        end

        {:noreply, state}

      {:error, :invalid_input} ->
        GenServer.cast(self(), {:warning, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby()}\n\n", Actors.Lobby.Messages.invalid_input_lobby(data)})
        {:noreply, state}
    end
  end

  # STATE - REGISTERED
  @impl true
  def handle_cast({:recv, data}, %{name: name, behavior: :opted_in} = state) do
    case Actors.Lobby.Regex.check_game_opt_out(data) do
      {:ok, :opt_out} ->
        case Actors.GameManager.remove_player(name) do
          # TODO: write a meaningfull error
          {:error, :user_not_registered} ->
            GenServer.cast(self(), {:warning, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.opted_in()}\n\n", "Player #{name} cannot be removed from that game because he didn't do the opt-in"})
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
    {:noreply, %{state | behavior: :forward_everything_to_player_actor}}
  end

  # STATE - GAME START
  @impl true
  def handle_cast({:recv, _} = envelop, %{player_actor: player_actor, behavior: :forward_everything_to_player_actor} = state) do
    GenServer.cast(player_actor, envelop)
    # GenServer.cast(player_actor, Tuple.insert_at(envelop, tuple_size(envelop), self()))

    {:noreply, state}
  end

  # DEGUB that match everything
  def handle_cast({x, _}, state) do
    IO.puts("Receiced " <> inspect(x) <> " behavior" <> inspect(state[:behavior]))

    {:noreply, state}
  end

  # - - -

  @impl true
  def init(%{client: client, name: name, parent_pid: parent_pid} = initial_state) do
    IO.puts("Actor.Lobby init" <> inspect(self()))
    IO.puts("Actor.Lobby monitor" <> inspect(parent_pid))

    Process.monitor(parent_pid)

    {:ok, pid} = Actors.Player.start_link(client, name, self())

    GenServer.cast(self(), {:message, "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby()}"})

    {:ok, %{initial_state | player_actor: pid}}
  end
end
