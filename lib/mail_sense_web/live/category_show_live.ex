defmodule MailSenseWeb.CategoryShowLive do
  use MailSenseWeb, :live_view

  alias MailSense.Accounts
  alias MailSense.Repo
  alias MailSense.Mail.Category
  alias MailSense.Mail.Email
  alias MailSense.Mail.GmailClient
  alias MailSense.Mail.MailContext

  def mount(%{"id" => id}, _session, socket) do
    category = Repo.get!(Category, id)

    emails = MailContext.list_emails_by_category(category.id)

    {:ok,
     socket
     |> assign(:category, category)
     |> assign(:emails, emails)
     |> assign(:selected, MapSet.new())}
  end

  def handle_event("toggle", %{"id" => id}, socket) do
    id = String.to_integer(id)
    selected = socket.assigns.selected

    selected =
      if MapSet.member?(selected, id),
        do: MapSet.delete(selected, id),
        else: MapSet.put(selected, id)

    {:noreply, assign(socket, :selected, selected)}
  end

  def handle_event("bulk_delete", %{"selected_ids" => ids_param}, socket) do
    ids =
      case ids_param do
        list when is_list(list) -> Enum.map(list, &String.to_integer/1)
        _ -> socket.assigns.selected |> MapSet.to_list()
      end

    user = socket.assigns.current_user
    emails = MailContext.list_emails_by_ids(user.id, ids)

    # Group messages by Gmail account to batch delete efficiently
    grouped =
      emails
      |> Enum.group_by(& &1.gmail_account_id)

    Enum.each(grouped, fn {acct_id, ems} ->
      acct = Repo.get!(Accounts.GmailAccount, acct_id)

      with {:ok, conn, _token} <- Accounts.google_connection(acct) do
        message_ids = Enum.map(ems, & &1.gmail_message_id)
        modify_gmail_labels(conn, acct.email, message_ids)
      end
    end)

    # Soft delete locally so the UI hides them, but history can be viewed later
    Email.mark_deleted_many!(emails)

    {:noreply,
     socket
     |> put_flash(:info, "#{length(emails)} emails deleted")
     |> assign(:selected, MapSet.new())
     |> assign(:emails, Enum.reject(socket.assigns.emails, &(&1.id in ids)))}
  end

  def handle_event("bulk_unsubscribe", %{"selected_ids" => ids}, socket) do
    user = socket.assigns.current_user
    emails = MailContext.list_emails_by_ids(user.id, ids)

    Enum.each(emails, fn email ->
      Oban.insert!(
        MailSense.Workers.BulkUnsubscribe.new(%{
          email_id: email.id,
          user_email: email.gmail_account.email
        })
      )
    end)

    {:noreply,
     socket
     |> put_flash(:info, "#{length(emails)} unsubscribe requests queued")
     |> push_patch(to: socket.assigns.current_path)}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex gap-2">
        <.button phx-click="bulk_delete">Delete</.button>
        <.button phx-click="bulk_unsubscribe">Unsubscribe</.button>
      </div>
      <table class="w-full">
        <thead>
          <tr>
            <th></th>
            <th>Summary</th>
            <th>Subject</th>
            <th>From</th>
            <th>Received</th>
          </tr>
        </thead>
        <tbody>
          <%= for e <- @emails do %>
            <tr>
              <td>
                <input type="checkbox" phx-click="toggle" phx-value-id={e.id} />
              </td>
              <td>{e.ai_summary}</td>
              <td>{e.subject}</td>
              <td>{e.from}</td>
              <td>{e.inserted_at}</td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp modify_gmail_labels(conn, email, message_ids) do
    Enum.map(message_ids, fn mid ->
      _ = GmailClient.modify_labels(conn, email, mid, ["TRASH"], [])
    end)
  end
end
