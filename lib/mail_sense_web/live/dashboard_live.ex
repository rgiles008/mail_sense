defmodule MailSenseWeb.DashboardLive do
  use MailSenseWeb, :live_view

  alias MailSense.Accounts

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:gmail_accounts, Accounts.list_gmail_accounts_for_user(user.id))
     |> assign(:categories, Accounts.list_categories_for_user(user.id))}
  end
end
