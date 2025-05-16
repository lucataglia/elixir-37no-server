defmodule Actors.Persistence.Auth do
  @moduledoc """
  Actors.Pesistence.Auth
  """

  use GenServer
  alias Utils.Colors
  alias Bcrypt, as: BCrypt

  @json_file "users.json"

  @register_user :register_user
  @authenticate :authenticate

  ## Public API

  # Start the GenServer
  def start_link() do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Register a new user with plaintext password
  def register_user(username, password) do
    GenServer.call(__MODULE__, {@register_user, username, password})
  end

  # Authenticate user login with username and password
  def authenticate(username, password) do
    GenServer.call(__MODULE__, {@authenticate, username, password})
  end

  ## GenServer Callbacks

  @impl true
  def init(_init_arg) do
    users = load_users()
    {:ok, users}
  end

  @impl true
  def handle_call({@register_user, username, password}, _from, users) do
    if Map.has_key?(users, username) do
      log("register_user user_already_exists")
      {:reply, {:error, :user_already_exists}, users}
    else
      log("register_user success")
      hashed_password = BCrypt.hash_pwd_salt(password)
      new_users = Map.put(users, username, hashed_password)
      save_users(new_users)
      {:reply, :ok, new_users}
    end
  end

  @impl true
  def handle_call({@authenticate, username, password}, _from, users) do
    log("authenticate")

    case Map.fetch(users, username) do
      {:ok, hashed_password} ->
        if BCrypt.verify_pass(password, hashed_password) do
          log("authenticate success")
          {:reply, {:ok, :authenticated}, users}
        else
          log("authenticate invalid_password")
          {:reply, {:error, :invalid_password}, users}
        end

      :error ->
        log("authenticate user_not_found")
        {:reply, {:error, :user_not_found}, users}
    end
  end

  ## Helper functions

  defp load_users do
    case File.read(@json_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, users} when is_map(users) -> users
          _ -> %{}
        end

      {:error, _} ->
        %{}
    end
  end

  defp save_users(users) do
    users
    |> Jason.encode!(pretty: true)
    |> (&File.write!(@json_file, &1)).()
  end

  # *** private api
  defp log(msg) do
    IO.puts("#{Colors.with_yellow_and_underline("Persistence.Auth")} #{msg}")
  end
end
