defmodule Actors.Bridge do
  @moduledoc """
  Actors.Bridge
  """

  use GenServer

  defp init_state(client) do
    %{
      behavior: :login,
      client: client,
      name: nil,
      recipient_actor: nil
    }
  end

  def start_link(client) do
    IO.puts("Actor.Bridge start_link" <> inspect(self()))

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
  def handle_cast({:success, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.success(msg))
    {:noreply, state}
  end

  # STOP
  @impl true
  def handle_cast({:stop}, state) do
    IO.puts("Actors.Bridge stop " <> inspect(self()))
    {:stop, :normal, state}
  end

  # FORWARD EVERYTHING Actor.Login
  @impl true
  def handle_cast({:recv, _} = envelop, %{client: client, recipient_actor: recipient_actor, behavior: :login} = state) do
    case GenServer.call(recipient_actor, envelop) do
      {:ok, :goto_lobby, name} ->
        {:ok, pid} = Actors.Lobby.start_link(client, name, self())

        {:noreply, %{state | name: name, recipient_actor: pid, behavior: :logged}}

      {:ok, _} ->
        {:noreply, state}

      {:error, _} ->
        {:noreply, state}
    end
  end

  # FORWARD EVERYTHING TO Actor.Lobby
  @impl true
  def handle_cast({:recv, _} = envelop, %{recipient_actor: recipient_actor, behavior: :logged} = state) do
    GenServer.cast(recipient_actor, envelop)

    {:noreply, state}
  end

  # GOTO MENU - Actor.Login new recipient
  @impl true
  def handle_cast({:goto_menu}, %{client: client} = state) do
    {:game, %{state | recipient_actor: Actors.Login.start_link(client, self())}}
  end

  # DEGUB that march everything
  def handle_cast({x, _}, state) do
    IO.puts("Receiced " <> inspect(x) <> " behavior" <> inspect(state[:behavior]))

    {:noreply, state}
  end

  # - - -

  @impl true
  def init(%{client: client} = initial_state) do
    IO.puts("Actor.Bridge init" <> inspect(self()))

    {:ok, pid} = Actors.Login.start_link(client, self())

    {:ok, %{initial_state | recipient_actor: pid}}
  end

  # *** Public api ***
  def forward_data(pid, data) do
    GenServer.cast(pid, {:recv, data})
  end

  def stop(pid) do
    GenServer.cast(pid, {:stop})
  end
end
