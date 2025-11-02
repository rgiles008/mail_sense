defmodule MailSense.Repo.Migrations.AddDeletedAtToEmails do
  use Ecto.Migration

  def change do
    alter table(:emails) do
      add :deleted_at, :utc_datetime
    end

    create index(:emails, [:deleted_at])
  end
end
