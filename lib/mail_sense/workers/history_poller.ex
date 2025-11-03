defmodule MailSense.Workers.HistoryPoller do
  use Oban.Worker,
    queue: :imports,
    max_attempts: 5

  alias MailSense.Accounts
  alias MailSense.Mail.GmailClient

  @impl true
  def perform(%Oban.Job{}) do
    for acct <- Accounts.list_gmail_accounts() do
      with {:ok, conn, _} <- Accounts.google_connection(acct),
           {:ok, hist} <- list_delta(conn, acct) do
        ids = extract_new_ids(hist)

        Enum.each(ids, fn mid ->
          Oban.insert!(
            MailSense.Workers.ImportMessage.new(%{
              gmail_account_id: acct.id,
              user_email: acct.email,
              message_id: mid
            })
          )
        end)

        _ =
          Accounts.update_gmail_account!(acct, %{
            history_id: hist.historyId,
            last_polled_at: DateTime.utc_now()
          })
      end
    end

    :ok
  end

  defp list_delta(conn, acct) do
    case acct.history_id do
      nil -> GmailClient.get_profile(conn, acct.email)
      hid -> GmailClient.list_history(conn, acct.email, hid)
    end
  end

  defp extract_new_ids(%GoogleApi.Gmail.V1.Model.ListHistoryResponse{history: history})
       when is_list(history) do
    history
    |> Enum.flat_map(&(&1.messagesAdded || []))
    |> Enum.map(& &1.message.id)
    |> Enum.uniq()
  end

  defp extract_new_ids(_), do: []
end
