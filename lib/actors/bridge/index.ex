defmodule Actors.Bridge do
  use GenServer

  defp init_state(client, recipient_actor) do
    %{
      behavior: :menu,
      client: client,
      name: nil,
      recipient_actor: recipient_actor
    }
  end

  def start_link(client) do
    IO.puts("Actor.Bridge start_link" <> inspect(self()))

    {:ok, pid} = Actors.Login.start_link(client)

    GenServer.start_link(__MODULE__, init_state(client, pid))
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
  def handle_cast({:stop} = envelop, %{recipient_actor: recipient_actor} = state) do
    GenServer.cast(recipient_actor, Tuple.insert_at(envelop, tuple_size(envelop), self()))
    {:stop, :normal, state}
  end

  # FORWARD EVERYTHING TO RECIPIENT
  @impl true
  def handle_cast({:recv, _} = envelop, %{recipient_actor: recipient_actor} = state) do
    GenServer.cast(recipient_actor, Tuple.insert_at(envelop, tuple_size(envelop), self()))

    {:noreply, state}
  end

  # GOTO LOBBY - Actor.Lobby new recipient
  @impl true
  def handle_cast({:goto_lobby, name}, %{client: client} = state) do
    {:ok, pid} = Actors.Lobby.start_link(client, self(), name)

    {:noreply, %{state | name: name, recipient_actor: pid}}
  end

  # GOTO MENU - Actor.Login new recipient
  @impl true
  def handle_cast({:goto_menu}, %{client: client} = state) do
    {:game, %{state | recipient_actor: Actors.Login.start_link(client)}}
  end

  # DEGUB that march everything
  def handle_cast({x, _}, state) do
    IO.inspect("Receiced " <> inspect(x) <> " behavior" <> inspect(state[:behavior]))

    {:noreply, state}
  end

  # - - -

  @impl true
  def init(initial_state) do
    IO.puts("Actor.Bridge init" <> inspect(self()))

    {:ok, initial_state}
  end

  # *** Public api ***
  def forward_data(pid, data) do
    GenServer.cast(pid, {:recv, data})
  end

  def stop(pid) do
    GenServer.cast(pid, {:stop})
  end
end
