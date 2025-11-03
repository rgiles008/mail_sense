defmodule MailSenseWeb.CategoryFormLive do
  use MailSenseWeb, :live_view
  use Phoenix.Component

  alias MailSense.Repo
  alias MailSense.Mail.Category

  def mount(_params, _session, socket) do
    {:ok, assign(socket, changeset: Category.changeset(%Category{}, {}))}
  end

  def handle_event("save", %{"category" => params} = all, socket) do
    user_id = socket.assigns.current_user.id

    rules_params =
      all["rules"] ||
        params["rules"] ||
        %{}

    rules = parse_rules(rules_params)

    attrs =
      params
      |> Map.put("user_id", user_id)
      |> Map.put("rules", rules)

    changeset = Category.changeset(%Category{}, attrs)

    case Repo.insert(changeset) do
      {:ok, _cat} ->
        {:noreply,
         socket
         |> put_flash(:info, "Category created")
         |> push_navigate(to: ~p"/")}

      {:error, cs} ->
        {:noreply, assign(socket, :changeset, cs)}
    end
  end

  def render(assigns) do
    ~H"""
    <h1 class="text-xl font-semibold mb-4">New Category</h1>
    <.form for={@changeset} phx-change="validate" phx-submit="save">
      <.input field={@changeset[:name]} label="Name" />
      <.input field={@changeset[:description]} label="Description" type="textarea" />
      <.input field={@changeset[:description]} label="Description" type="textarea" />
      <.input field={@changeset[:exemplar]} label="Example phrases (one per line)" type="textarea" />

      <h3 class="mt-6 font-semibold">Rules</h3>
      <div class="grid grid-cols-2 gap-4">
        <.input name="rules[subject_includes]" label="Subject includes (comma-separated)" />
        <.input name="rules[from_domains]" label="From domains (comma-separated)" />
        <label class="flex items-center gap-2">
          <input type="checkbox" name="rules[has_unsubscribe]" /> Needs unsubscribe header
        </label>
        <.input name="rules[boosts]" label="Boost (/-)" />
        <.input name="rules[penalty]" label="Penalty (/-)" />
      </div>
      <.button>Save</.button>
    </.form>
    """
  end

  defp parse_rules(rules_params) when is_map(rules_params) do
    %{
      "subject_includes" => split_list(Map.get(rules_params, "subject_includes")),
      "from_domains" => split_list(Map.get(rules_params, "from_domains")),
      "has_unsubscribe" => truthy?(Map.get(rules_params, "has_unsubscribe")),
      "boosts" => to_float(Map.get(rules_params, "boosts")),
      "penalty" => to_float(Map.get(rules_params, "penalty"))
    }
    |> reject_empty_values()
  end

  defp split_list(nil), do: []

  defp split_list(val) when is_binary(val) do
    val
    |> String.split([",", "\n"], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp split_list(_), do: []

  defp truthy?(v) when is_binary(v), do: v in ["true", "on", "1", "yes"]
  defp truthy?(v) when is_boolean(v), do: v
  defp truthy?(_), do: false

  defp to_float(nil), do: 0.0
  defp to_float(""), do: 0.0

  defp to_float(v) when is_binary(v) do
    case Float.parse(v) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  defp to_float(v) when is_number(v), do: v * 1.0
  defp to_float(_), do: 0.0

  defp reject_empty_values(map) do
    map
    |> Enum.reject(fn
      {_k, v} when is_list(v) -> v == []
      {_k, v} when is_binary(v) -> v == ""
      # keep booleans and numbers, including 0.0
      _ -> false
    end)
    |> Map.new()
  end
end
