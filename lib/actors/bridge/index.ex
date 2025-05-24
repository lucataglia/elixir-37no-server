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
    Utils.Log.log("Bridge", "Actor.Bridge start_link" <> inspect(self()), &Utils.Colors.with_cyan/1)

    GenServer.start_link(__MODULE__, init_state(client))
  end

  # HANDLE INFO
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, {:shutdown, :lobby_shutdown_back_msg}}, %{client: client} = state) do
    Utils.Log.log("Bridge", "Monitored process #{inspect(pid)} exited with reason #{inspect({:shutdown, :back})}", &Utils.Colors.with_cyan/1)

    {:ok, pid} = Actors.Login.start(client, self())

    {:noreply, %{state | login_actor: pid, lobby_actor: nil, behavior: :login}}
  end

  # STOP
  @impl true
  def handle_cast({@exit}, state) do
    Utils.Log.log("Bridge", "Client #{Colors.with_underline("exit")} - Actors.Bridge stop himself " <> inspect(self()), &Utils.Colors.with_cyan/1)
    {:stop, {:shutdown, :bridge_shutdown_client_exit}, state}
  end

  @impl true
  def handle_cast({@client_disconected}, state) do
    Utils.Log.log("Bridge", "Client #{Colors.with_underline("disconected")} - Actors.Bridge stop himself " <> inspect(self()), &Utils.Colors.with_cyan/1)
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
  def handle_cast({@recv, _} = envelop, %{name: n, lobby_actor: lobby_actor, behavior: :logged} = state) do
    Utils.Log.log("Bridge", n, inspect(envelop), &Utils.Colors.with_cyan/1)
    GenServer.cast(lobby_actor, envelop)

    {:noreply, state}
  end

  # DEGUB that march everything
  def handle_cast({x, _}, state) do
    Utils.Log.log("Bridge", "Receiced " <> inspect(x) <> " behavior" <> inspect(state[:behavior]), &Utils.Colors.with_cyan/1)

    {:noreply, state}
  end

  # - - -

  @impl true
  def init(%{client: client} = initial_state) do
    Utils.Log.log("Bridge", "Actor.Bridge init" <> inspect(self()), &Utils.Colors.with_cyan/1)

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
end
