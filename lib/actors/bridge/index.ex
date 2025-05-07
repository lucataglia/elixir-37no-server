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
      recipient_actor: nil
    }
  end

  def start_link(client) do
    IO.puts("Actor.Bridge start_link" <> inspect(self()))

    GenServer.start_link(__MODULE__, init_state(client))
  end

  # STOP
  @impl true
  def handle_cast({@exit}, state) do
    IO.puts("Client #{Colors.with_underline("exit")} - Actors.Bridge stop himself " <> inspect(self()))
    {:stop, :normal, state}
  end

  @impl true
  def handle_cast({@client_disconected}, state) do
    IO.puts("Client #{Colors.with_underline("disconected")} - Actors.Bridge stop himself " <> inspect(self()))
    {:stop, :normal, state}
  end

  # *** END STOP

  # FORWARD EVERYTHING Actor.Login
  @impl true
  def handle_cast({@recv, _} = envelop, %{client: client, recipient_actor: recipient_actor, behavior: :login} = state) do
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
  def handle_cast({@recv, _} = envelop, %{recipient_actor: recipient_actor, behavior: :logged} = state) do
    GenServer.cast(recipient_actor, envelop)

    {:noreply, state}
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
    GenServer.cast(pid, {@recv, data})
  end

  def client_disconected(pid) do
    GenServer.cast(pid, {@client_disconected})
  end

  def exit(pid) do
    GenServer.cast(pid, {@exit})
  end
end
