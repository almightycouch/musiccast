defmodule GenImpl do
  defmacro __using__(options) do
    module = Macro.expand(Keyword.fetch!(options, :for), __ENV__)
    for {fun, arity} <- module.__info__(:functions) do
      args = Enum.map(Enum.drop(0..arity-1, 1),&Macro.var(:"arg#{&1}", module))
      quote do
        @doc "See `#{unquote(module)}.#{unquote(fun)}/#{unquote(arity)}`."
        def unquote(fun)(pid, unquote_splicing(args)) do
          GenServer.call(pid, {:gen_impl, unquote(module), {unquote(fun), unquote(args)}})
        end
      end
    end
  end
end
