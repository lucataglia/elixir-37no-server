defmodule Actors.Bridge do
  @moduledoc """
  Actors.Bridge
  """
  alias Utils.Colors

  use GenServer

  @client_disconected :client_disconected
  @exit :exit
  @recv :recv

  defp init_state(client) do
    %{
      behavior: :login,
      client: client,
      name: nil,
      login_actor: nil,
      lobby_actor: nil
    }
  end

  def start_link(client) do
    log("Actor.Bridge start_link" <> inspect(self()))

    GenServer.start_link(__MODULE__, init_state(client))
  end

  # HANDLE INFO
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, {:shutdown, :lobby_shutdown_back_msg}}, %{client: client} = state) do
    log("Monitored process #{inspect(pid)} exited with reason #{inspect({:shutdown, :back})}")

    {:ok, pid} = Actors.Login.start(client, self())

    {:noreply, %{state | login_actor: pid, lobby_actor: nil, behavior: :login}}
  end

  # STOP
  @impl true
  def handle_cast({@exit}, state) do
    log("Client #{Colors.with_underline("exit")} - Actors.Bridge stop himself " <> inspect(self()))
    {:stop, {:shutdown, :bridge_shutdown_client_exit}, state}
  end

  @impl true
  def handle_cast({@client_disconected}, state) do
    log("Client #{Colors.with_underline("disconected")} - Actors.Bridge stop himself " <> inspect(self()))
    {:stop, {:shutdown, :bridge_shutdown_client_exit}, state}
  end

  # *** END STOP

  # FORWARD EVERYTHING Actor.Login
  @impl true
  def handle_cast({@recv, _} = envelop, %{client: client, login_actor: login_actor, behavior: :login} = state) do
    case GenServer.call(login_actor, envelop) do
      {:ok, :goto_lobby, name} ->
        {:ok, pid} = Actors.Lobby.start(client, name, self())

        # e.g. {:shutdown, :lobby_shutdown_back_msg}
        Process.monitor(pid)

        {:noreply, %{state | name: name, login_actor: nil, lobby_actor: pid, behavior: :logged}}

      {:ok, _} ->
        {:noreply, state}

      {:error, _} ->
        {:noreply, state}
    end
  end

  # FORWARD EVERYTHING TO Actor.Lobby
  @impl true
  def handle_cast({@recv, _} = envelop, %{lobby_actor: lobby_actor, behavior: :logged} = state) do
    GenServer.cast(lobby_actor, envelop)

    {:noreply, state}
  end

  # DEGUB that march everything
  def handle_cast({x, _}, state) do
    log("Receiced " <> inspect(x) <> " behavior" <> inspect(state[:behavior]))

    {:noreply, state}
  end

  # - - -

  @impl true
  def init(%{client: client} = initial_state) do
    log("Actor.Bridge init" <> inspect(self()))

    {:ok, pid} = Actors.Login.start(client, self())

    {:ok, %{initial_state | login_actor: pid}}
  end

  # *** Public api ***
  def forward_data(pid, data) do
    GenServer.cast(pid, {@recv, data})
  end

  def client_disconected(pid) do
    GenServer.cast(pid, {@client_disconected})
  end

  def exit(pid) do
    GenServer.cast(pid, {@exit})
  end

  # *** private api
  defp log(msg) do
    IO.puts("#{Colors.with_cyan("Bridge")} #{msg}")
  end
end
