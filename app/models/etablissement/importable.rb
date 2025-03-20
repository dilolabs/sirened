module Etablissement::Importable
  extend ActiveSupport::Concern

  require "csv"
  require "net/http"
  require "zip"

  included do
    BATCH_SIZE = 10_000
    ZIP_SOURCE = "https://files.data.gouv.fr/insee-sirene/StockEtablissement_utf8.zip"
    ZIP_DESTINATION = Rails.root.join("storage", "StockEtablissement_utf8.zip")
    CSV_DESTINATION = Rails.root.join("storage", "StockEtablissement_utf8.csv")

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
            entry.extract(destination) if entry.name.include?("StockEtablissement_utf8.csv")
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

      etablissements_to_create = []
      etablissements_to_update = []

      CSV.foreach(source, headers: true, col_sep: ",") do |row|
        row_hash = row.to_h

        existing_etablissement = Etablissement.find_by(siret: row_hash["siret"])
        if existing_etablissement
          etablissements_to_update << row_hash.merge(id: existing_etablissement.id, unite_legale_id: existing_etablissement.unite_legale_id)
        else
          unite_legale = UniteLegale.find_by(siren: row_hash["siren"])
          next unless unite_legale
          etablissements_to_create << row_hash.merge(unite_legale_id: unite_legale.id)
        end

        if etablissements_to_create.size >= BATCH_SIZE
          Etablissement.insert_all(etablissements_to_create, unique_by: :siret)
          Rails.logger.info "Processed batch"
          etablissements_to_create.clear
        end

        if etablissements_to_update.size >= BATCH_SIZE
          Etablissement.upsert_all(etablissements_to_update, unique_by: :id)
          Rails.logger.info "Processed batch"
          etablissements_to_update.clear
        end
      end

      # Insert any remaining records
      unless etablissements_to_create.empty?
        Etablissement.insert_all(etablissements_to_create, unique_by: :siret)
      end
      unless etablissements_to_update.empty?
        Etablissement.upsert_all(etablissements_to_update, unique_by: :id)
      end

      Rails.logger.info "Imported #{source}"
    rescue StandardError => e
      Rails.logger.error "Error during CSV import: #{e.message}"
      raise
    end
  end
end
