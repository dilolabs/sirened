module UniteLegale::Importable
  extend ActiveSupport::Concern

  require "csv"
  require "net/http"
  require "zip"

  included do
    BATCH_SIZE = 10_000
    ZIP_SOURCE = "https://files.data.gouv.fr/insee-sirene/StockUniteLegale_utf8.zip"
    ZIP_DESTINATION = Rails.root.join("storage", "StockUniteLegale_utf8.zip")
    CSV_DESTINATION = Rails.root.join("storage", "StockUniteLegale_utf8.csv")

    def self.import_stock
      delete_stock
      download_stock
      unzip_stock
      import_csv
    end

    private

    def self.delete_stock
      File.delete(ZIP_DESTINATION) if File.exist?(ZIP_DESTINATION)
      File.delete(CSV_DESTINATION) if File.exist?(CSV_DESTINATION)
    end

    def self.download_stock(source: ZIP_SOURCE, destination: ZIP_DESTINATION)
      Rails.logger.info "Starting download of #{source} to #{destination}"
      begin
        uri = URI.parse(source)
        response = Net::HTTP.get_response(uri)

        if response.is_a?(Net::HTTPSuccess)
          File.open(destination, 'wb') do |file|
            file.write(response.body)
          end
          Rails.logger.info "Successfully downloaded to #{destination}"
        else
          Rails.logger.error "Failed to download file. HTTP Status: #{response.code} - #{response.message}"
          raise "Download failed"
        end
      rescue StandardError => e
        Rails.logger.error "Error during download: #{e.message}"
        raise
      end
    end

    def self.unzip_stock(source: ZIP_DESTINATION, destination: CSV_DESTINATION)
      Rails.logger.info "Unzipping #{source} to #{destination.dirname}"
      begin
        Zip::File.open(source) do |zip_file|
          zip_file.each do |entry|
            entry.extract(destination) if entry.name.include?("StockUniteLegale_utf8.csv")
          end
        end
        Rails.logger.info "Successfully unzipped to #{destination}"
      rescue StandardError => e
        Rails.logger.error "Error during unzip: #{e.message}"
        raise
      end
    end

    def self.import_csv(source: CSV_DESTINATION)
      Rails.logger.info "Importing CSV from #{source}"

      disable_triggers

      unites_legales_to_upsert = []

      begin
        CSV.foreach(source, headers: true, col_sep: ",") do |row|
          unites_legales_to_upsert << row.to_h

          if unites_legales_to_upsert.size >= BATCH_SIZE
            UniteLegale.upsert_all(unites_legales_to_upsert, unique_by: :siren)
            Rails.logger.info "Processed batch"
            unites_legales_to_upsert.clear
          end
        end

        # Insert any remaining records
        unless unites_legales_to_upsert.empty?
          UniteLegale.upsert_all(unites_legales_to_upsert, unique_by: :siren)
        end

        Rails.logger.info "CSV import completed successfully"
      rescue StandardError => e
        Rails.logger.error "Error during CSV import: #{e.message}"
        raise
      ensure
        enable_triggers
        update_tsvector
      end
    end

    def self.disable_triggers
      ActiveRecord::Base.connection.execute("ALTER TABLE unite_legales DISABLE TRIGGER ALL;")
      Rails.logger.info "Triggers on unite_legales table disabled"
    rescue StandardError => e
      Rails.logger.error "Failed to disable triggers: #{e.message}"
      raise
    end

    def self.enable_triggers
      ActiveRecord::Base.connection.execute("ALTER TABLE unite_legales ENABLE TRIGGER ALL;")
      Rails.logger.info "Triggers on unite_legales table re-enabled"
    rescue StandardError => e
      Rails.logger.error "Failed to enable triggers: #{e.message}"
      raise
    end

    def self.update_tsvector
      Rails.logger.info "Updating tsvector for unite_legales"
      ActiveRecord::Base.connection.execute <<-SQL.squish
      UPDATE unite_legales SET tsvector_nom_tsearch = (
        setweight(to_tsvector('pg_catalog.french', coalesce("denominationUniteLegale", '')), 'A') ||
        setweight(to_tsvector('pg_catalog.french', coalesce("nomUniteLegale", '')), 'B')
      );
      SQL
      Rails.logger.info "tsvector updated successfully"
    end
  end
end
