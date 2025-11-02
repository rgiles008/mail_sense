defmodule MailSenseWeb.CategoryFormLive do
  use MailSenseWeb, :live_view
  use Phoenix.Component

  alias MailSense.Repo
  alias MailSense.Mail.Category

  def mount(_params, _session, socket) do
    {:ok, assign(socket, changeset: Category.changeset(%Category{}, {}))}
  end

  def handle_event("save", %{"category" => params}, socket) do
    params = Map.put(params, "user_id", socket.assigns.current_user.id)

    case %Category{} |> Category.changeset(params) |> Repo.insert() do
      {:ok, _} -> {:noreply, push_navigate(socket, to: "/")}
      {:error, cs} -> {:noreply, assign(socket, :changeset, cs)}
    end
  end

  def render(assigns) do
    ~H"""
    <h1 class="text-xl font-semibold mb-4">New Category</h1>
    <.form for={@changeset} phx-change="validate" phx-submit="save">
      <.input field={@changeset[:name]} label="Name" />
      <.input field={@changeset[:description]} label="Description" type="textarea" />
      <.button>Save</.button>
    </.form>
    """
  end
end
