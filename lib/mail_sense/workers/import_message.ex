defmodule MailSense.Workers.ImportMessage do
  use Oban.Worker, queue: :ai, max_attempts: 3
  alias MailSense.Repo
  alias MailSense.Accounts
  alias MailSense.Mail.Email
  alias MailSense.Mail.GmailClient
  alias MailSense.Mail.Classifier
  alias MailSense.Mail.AI
  alias MailSense.Mail.MailContext

  @impl true
  def perform(%Oban.Job{
        args: %{"gmail_account_id" => acct_id, "user_email" => uemail, "message_id" => mid}
      }) do
    acct = Repo.get!(MailSense.Accounts.GmailAccount, acct_id)
    {:ok, conn, _} = Accounts.google_connection(acct)
    {:ok, msg} = GmailClient.get_message(conn, uemail, mid, "full")
    parsed = Email.parse_gmail_message(msg)

    cats = Accounts.list_categories_for_user(acct.user_id)

    case Classifier.choose_category(parsed, cats) do
      {:ok, cat} ->
        {:ok, summary} = ensure_summary(parsed)
        MailContext.persist_categorized!(acct, parsed, cat, summary)
        _ = MailContext.archive_and_label(conn, uemail, mid, cat)
        :ok

      {:tie, _top, candidates} ->
        with {:ok, %{"category" => name, "summary" => summary}} <-
               AI.tie_break_and_summarize(parsed, candidates),
             cat <- Accounts.get_or_create_category_by_name!(acct.user_id, name) do
          MailContext.persist_categorized!(acct, parsed, cat, summary)
          _ = MailContext.archive_and_label(conn, uemail, mid, cat)
          :ok
        else
          _ -> :ok
        end

      :none ->
        :ok
    end
  end

  defp ensure_summary(parsed) do
    if byte_size(parsed.body_text || "") > 0 do
      AI.summarize(parsed)
    else
      {:ok, parsed.snippet || "(no content)"}
    end
  end
end
