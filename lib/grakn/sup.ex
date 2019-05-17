defmodule Grakn.Sup do
  @moduledoc false
  use Supervisor

  alias Multix.OnGet

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    {servers, opts} = Keyword.pop(opts, :servers)

    {children, conn_names} =
      Enum.flat_map_reduce(servers, [], fn server_opts, conn_names ->
        {child_spec, conn_name} = named_child(name, opts, server_opts)
        {[child_spec], [conn_name | conn_names]}
      end)

    multix_opts = [name: name, resources: conn_names, on_get: OnGet.Random, on_failure: Grakn]
    Supervisor.init([{Multix.Sup, multix_opts} | children], strategy: :one_for_one)
  end

  defp named_child(name, opts, server_opts) do
    conn_opts = Keyword.merge(opts, server_opts)
    connection_uri = Grakn.connection_uri(conn_opts)
    conn_name = grakn_child_name(name, connection_uri)
    child_spec = {Grakn, Keyword.put(conn_opts, :name, conn_name)}
    {child_spec, conn_name}
  end

  # There is generated one atom per server endpoint, so it should be ok for now.
  defp grakn_child_name(name, connection_uri), do: :"#{name}_#{connection_uri}"
end
