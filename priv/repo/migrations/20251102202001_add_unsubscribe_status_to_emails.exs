defmodule MailSense.Repo.Migrations.AddUnsubscribeStatusToEmails do
  use Ecto.Migration

  def change do
    alter table(:emails) do
      add :unsubscribe_status, :string, default: "none", null: false
      add :unsubscribed_at, :utc_datetime
      add :unsubscribe_error, :text
      add :last_unsubscribe_attempt_at, :utc_datetime
    end

    create index(:emails, [:unsubscribe_status])
  end
end
