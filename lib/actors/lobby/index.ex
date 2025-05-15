defmodule Actors.Lobby do
  @moduledoc """
  Actors.Lobby
  """
  alias Utils.Colors

  use GenServer

  @behavior_lobby :behavior_lobby
  @behavior_opted_in :behavior_opted_in
  @behavior_forward_everything_to_player_actor :behavior_forward_everything_to_player_actor

  @game_start :game_start
  @msg_info :msg_info
  @msg_success :msg_success
  @msg_warning :msg_warning
  @recv :recv

  defp init_state(client, name, bridge_pid) do
    %{
      behavior: @behavior_lobby,
      client: client,
      name: name,
      bridge_pid: bridge_pid,
      player_pid: nil
    }
  end

  def start(client, name, bridge_pid) do
    log(name, "Actor.Lobby start " <> inspect(self()))

    GenServer.start(__MODULE__, init_state(client, name, bridge_pid))
  end

  def start_link(client, name, bridge_pid) do
    log(name, "Actor.Lobby start_link " <> inspect(self()))

    GenServer.start_link(__MODULE__, init_state(client, name, bridge_pid))
  end

  # HANDLE INFO
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, {:shutdown, :bridge_shutdown_client_exit} = reason}, %{name: name, behavior: behavior} = state) do
    log(name, ":DOWN Bridge #{inspect(pid)} exited with reason #{inspect(reason)}")

    case behavior do
      @behavior_lobby ->
        log(name, "behavior #{behavior} - do nothing")

      @behavior_opted_in ->
        log(name, "behavior #{behavior} - opt_out")

        case Actors.GameManager.remove_player(name) do
          {:error, :user_not_registered} ->
            log(name, "behavior #{behavior} - opt_out - user_not_registered")

          {:ok, _} ->
            log(name, "behavior #{behavior} - opt_out - ok")
        end

      @behavior_forward_everything_to_player_actor ->
        log(name, "behavior #{behavior} - do nothing")
    end

    {:stop, reason, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, {:shutdown, :player_shutdown_left_the_game} = reason}, %{client: client, name: name, bridge_pid: bridge_pid}) do
    log(name, ":DOWN Player #{inspect(pid)} left the table #{inspect(reason)}")

    info_message(self(), message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}")

    {:noreply, init_state(client, name, bridge_pid)}
  end

  # *** END HANDLE INFO

  # TERMINATE (for debug at the moment)
  @impl true
  def terminate(reason, %{name: n} = state) do
    log(n, "GenServer stopping with reason: #{inspect(reason)} and state: #{inspect(state)}")
    :ok
  end

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
  def handle_cast({@recv, data}, %{client: client, name: name, behavior: @behavior_lobby} = state) do
    case Actors.Lobby.Regex.check_game_opt_in(data) do
      {:ok, :opt_in} ->
        {:ok, player_pid} = Actors.Player.start(client, name, self())

        case Actors.GameManager.add_player(name, player_pid) do
          {:error, :user_already_registered} ->
            warning_message(self(), message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}\n\n", piggiback: Actors.Lobby.Messages.user_already_opted_in(name))

            Process.exit(player_pid, :normal)

            {:noreply, state}

          {:ok, :user_opted_in, msg} ->
            success_message(self(), message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.opted_in()}\n\n", piggiback: msg)

            Process.monitor(player_pid)

            {:noreply, %{state | player_pid: player_pid, behavior: @behavior_opted_in}}

          {:ok, :game_start} ->
            Process.monitor(player_pid)

            {:noreply, %{state | player_pid: player_pid, behavior: @behavior_opted_in}}
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
        {:ok, player_pid} = Actors.Player.start(client, name, self())

        case Actors.GameManager.rejoin(name, uuid, player_pid) do
          {:ok, :table_manager_informed} ->
            warning_message(self(), message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}\n\n", piggiback: "Please wait...")

            Process.monitor(player_pid)

            {:noreply, state}

          {:error, :game_does_not_exist} ->
            warning_message(self(),
              message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}\n\n",
              piggiback: "Game #{Colors.with_underline(uuid)} does not exist. It may have been terminated."
            )

            Process.exit(player_pid, :normal)

            {:noreply, state}
        end

      {:ok, :observe, uuid} ->
        {:ok, player_pid} = Actors.Player.start(client, name, self())

        case Actors.GameManager.observe(name, uuid, player_pid) do
          {:ok, :table_manager_informed} ->
            warning_message(self(),
              message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}\n\n",
              piggiback: "Please wait..."
            )

            Process.monitor(player_pid)

            {:noreply, state}

          {:error, :game_does_not_exist} ->
            warning_message(self(),
              message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}\n\n",
              piggiback: "Game #{Colors.with_underline(uuid)} does not exist. It may have been terminated."
            )

            Process.exit(player_pid, :normal)

            {:noreply, state}
        end

        {:noreply, state}

      {:ok, :back} ->
        {:stop, {:shutdown, :lobby_shutdown_back_msg}, state}

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
  def handle_cast({@game_start}, %{name: name} = state) do
    case state[:behavior] do
      # e.g. rejoin
      @behavior_lobby ->
        log(name, "Game start")
        {:noreply, %{state | behavior: @behavior_forward_everything_to_player_actor}}

      # e.g. game start
      @behavior_opted_in ->
        log(name, "Game start")
        {:noreply, %{state | behavior: @behavior_forward_everything_to_player_actor}}

      # this should never happen
      _ ->
        log(name, "Error: got :game_start in #{state[:behavior]} behavior")
        {:noreply, state}
    end
  end

  # STATE - GAME START
  @impl true
  def handle_cast({@recv, _} = envelop, %{player_pid: player_pid, behavior: @behavior_forward_everything_to_player_actor} = state) do
    GenServer.cast(player_pid, envelop)
    # GenServer.cast(player_pid, Tuple.insert_at(envelop, tuple_size(envelop), self()))

    {:noreply, state}
  end

  # DEGUB that match everything
  def handle_cast({x, _}, %{name: name} = state) do
    log_debug(name, "Receiced " <> inspect(x) <> " behavior" <> inspect(state[:behavior]))

    {:noreply, state}
  end

  # - - -

  @impl true
  def init(%{name: name, bridge_pid: bridge_pid} = initial_state) do
    log(name, "Actor.Lobby init " <> inspect(self()))

    Process.monitor(bridge_pid)

    info_message(self(), message: "#{Messages.title()}\n\n#{Actors.Lobby.Messages.lobby(name)}")

    {:ok, initial_state}
  end

  @spec info_message(atom() | pid() | {atom(), any()} | {:via, atom(), any()}, keyword()) :: :ok
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

  # *** private api
  defp log(name, msg) do
    IO.puts("#{Colors.with_magenta("Lobby")} #{name}: #{msg}")
  end

  defp log_debug(name, msg) do
    IO.puts("#{Colors.with_red_bright("Lobby (DEBUG)")} #{name}: #{msg}")
  end
end
