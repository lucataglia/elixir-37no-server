defmodule Actors.Lobby do
  @moduledoc """
  Actors.Lobby
  """
  alias Utils.Colors

  use GenServer

  @behavior_lobby :behavior_lobby
  @behavior_opted_in :behavior_opted_in
  @forward_everything_to_player_actor :forward_everything_to_player_actor
  @game_start :game_start
  @msg_info :msg_info
  @msg_success :msg_success
  @msg_warning :msg_warning
  @recv :recv

  defp init_state(client, name, parent_pid) do
    %{
      behavior: @behavior_lobby,
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
  def handle_info({:DOWN, _ref, :process, _pid, reason}, %{name: name, behavior: @behavior_opted_in} = state) do
    IO.puts("#{Colors.with_magenta("[#{name}]")} (Lobby) Parent process stopped with reason: #{inspect(reason)}")

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

  # *** ENDHandle :DOWN message when the parent dies

  # PRINT MESSAGES
  @impl true
  def handle_cast({@msg_info, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.message(msg))
    {:noreply, state}
  end

  @impl true
  def handle_cast({@msg_info, msg, piggiback}, %{client: client} = state) do
    :gen_tcp.send(client, "#{msg}#{Messages.message(piggiback)}")
    {:noreply, state}
  end

  @impl true
  def handle_cast({@msg_warning, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.warning(msg))
    {:noreply, state}
  end

  @impl true
  def handle_cast({@msg_warning, msg, piggiback}, %{client: client} = state) do
    :gen_tcp.send(client, "#{msg}#{Messages.warning(piggiback)}")
    {:noreply, state}
  end

  @impl true
  def handle_cast({@msg_success, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.success(msg))
    {:noreply, state}
  end

  @impl true
  def handle_cast({@msg_success, msg, piggiback}, %{client: client} = state) do
    :gen_tcp.send(client, "#{msg}#{Messages.success(piggiback)}")
    {:noreply, state}
  end

  # *** ENDPRINT MESSAGES

  # STATE - LOBBY
  @impl true
  def handle_cast({@recv, data}, %{name: name, player_actor: player_actor, behavior: @behavior_lobby} = state) do
    case Actors.Lobby.Regex.check_game_opt_in(data) do
      {:ok, :opt_in} ->
        case Actors.GameManager.add_player(name, player_actor) do
          {:error, :user_already_registered} ->
            warning_message(self(), message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}\n\n", piggiback: Actors.Lobby.Messages.user_already_opted_in(name))

            {:noreply, state}

          {:ok, :user_opted_in, msg} ->
            success_message(self(), message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.opted_in()}\n\n", piggiback: msg)

            {:noreply, %{state | behavior: @behavior_opted_in}}

          {:ok, :game_start} ->
            {:noreply, %{state | behavior: @behavior_opted_in}}
        end

      {:ok, :list_my_open_tables} ->
        case Actors.GameManager.list_open_tables(name) do
          {:ok, :no_active_game} ->
            info_message(self(), message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}\n\n", piggiback: "You have zero game in progess")

            {:noreply, state}

          {:ok, list} ->
            msg = Enum.map(list, fn {game_uuid, game_desc} -> "#{Colors.with_underline("rejoin #{game_uuid}")} - #{game_desc}" end)
            info_message(self(), message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}\n\n", piggiback: msg)

            {:noreply, state}
        end

      {:ok, :list_all_open_tables} ->
        case Actors.GameManager.list_all_open_tables() do
          {:ok, list} when list == [] ->
            info_message(self(), message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}\n\n", piggiback: "There are zero games in progess")

            {:noreply, state}

          {:ok, list} ->
            msg = Enum.map(list, fn {game_uuid, game_desc} -> "#{Colors.with_underline("observe #{game_uuid}")} - #{game_desc}" end)
            info_message(self(), message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}\n\n", piggiback: msg)

            {:noreply, state}
        end

      {:ok, :rejoin, uuid} ->
        case Actors.GameManager.rejoin(name, uuid, player_actor) do
          {:ok, :table_manager_informed} ->
            warning_message(self(), message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}\n\n", piggiback: "Please wait...")

            {:noreply, state}

          {:error, :game_does_not_exist} ->
            warning_message(self(),
              message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}\n\n",
              piggiback: "Game #{Colors.with_underline(uuid)} does not exist. It may have been terminated."
            )

            {:noreply, state}
        end

      {:ok, :observe, uuid} ->
        case Actors.GameManager.observe(name, uuid, player_actor) do
          {:ok, :table_manager_informed} ->
            warning_message(self(),
              message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}\n\n",
              piggiback: "Please wait..."
            )

            {:noreply, state}

          {:error, :game_does_not_exist} ->
            warning_message(self(),
              message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}\n\n",
              piggiback: "Game #{Colors.with_underline(uuid)} does not exist. It may have been terminated."
            )

            {:noreply, state}
        end

        {:noreply, state}

      {:error, :invalid_input} ->
        warning_message(self(),
          message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}\n\n",
          piggiback: Actors.Lobby.Messages.invalid_input_lobby(data)
        )

        {:noreply, state}
    end
  end

  # STATE - REGISTERED
  @impl true
  def handle_cast({@recv, data}, %{name: name, behavior: @behavior_opted_in} = state) do
    case Actors.Lobby.Regex.check_game_opt_out(data) do
      {:ok, :opt_out} ->
        case Actors.GameManager.remove_player(name) do
          {:error, :user_not_registered} ->
            warning_message(self(),
              message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.opted_in()}\n\n",
              piggiback: "Player #{name} cannot be removed from that game because he didn't do the opt-in"
            )

            {:noreply, state}

          {:ok, msg} ->
            success_message(self(), message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}\n\n", piggiback: msg)

            {:noreply, %{state | behavior: @behavior_lobby}}
        end

      {:error, :invalid_input} ->
        warning_message(self(),
          message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.opted_in()}\n\n",
          piggiback: Actors.Lobby.Messages.invalid_input_opted_in(data)
        )

        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({@game_start}, state) do
    case state[:behavior] do
      # e.g. rejoin
      @behavior_lobby ->
        {:noreply, %{state | behavior: @forward_everything_to_player_actor}}

      # e.g. game start
      @behavior_opted_in ->
        {:noreply, %{state | behavior: @forward_everything_to_player_actor}}

      # this should never happen
      _ ->
        IO.puts(Colors.with_magenta("Error: got :game_start in #{state[:behavior]} behavior"))
        {:noreply, state}
    end
  end

  # STATE - GAME START
  @impl true
  def handle_cast({@recv, _} = envelop, %{player_actor: player_actor, behavior: @forward_everything_to_player_actor} = state) do
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

    info_message(self(), message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}")

    {:ok, %{initial_state | player_actor: pid}}
  end

  def info_message(pid, opts) do
    msg = Keyword.get(opts, :message, "")
    piggiback = Keyword.get(opts, :piggiback, "")

    if piggiback do
      GenServer.cast(pid, {@msg_info, msg, piggiback})
    else
      GenServer.cast(pid, {@msg_info, piggiback})
    end
  end

  def warning_message(pid, opts) do
    msg = Keyword.get(opts, :message, "")
    piggiback = Keyword.get(opts, :piggiback, "")

    if piggiback do
      GenServer.cast(pid, {@msg_warning, msg, piggiback})
    else
      GenServer.cast(pid, {@msg_warning, piggiback})
    end
  end

  def success_message(pid, opts) do
    msg = Keyword.get(opts, :message, "")
    piggiback = Keyword.get(opts, :piggiback, "")

    if piggiback do
      GenServer.cast(pid, {@msg_success, msg, piggiback})
    else
      GenServer.cast(pid, {@msg_success, piggiback})
    end
  end

  def game_start(pid) do
    GenServer.cast(pid, {@game_start})
  end
end
