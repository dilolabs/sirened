# == Schema Information
#
# Table name: unite_legales
#
#  id                                        :uuid             not null, primary key
#  activitePrincipaleUniteLegale             :string
#  anneeCategorieEntreprise                  :integer
#  anneeEffectifsUniteLegale                 :integer
#  caractereEmployeurUniteLegale             :string
#  categorieEntreprise                       :string
#  categorieJuridiqueUniteLegale             :integer
#  changementEtatAdministratifUniteLegale    :string
#  dateCreationUniteLegale                   :date
#  dateDebut                                 :date
#  dateDernierTraitementUniteLegale          :datetime
#  denominationUniteLegale                   :string
#  denominationUsuelle1UniteLegale           :string
#  denominationUsuelle2UniteLegale           :string
#  denominationUsuelle3UniteLegale           :string
#  economieSocialeSolidaireUniteLegale       :string
#  etatAdministratifUniteLegale              :string
#  identifiantAssociationUniteLegale         :string
#  nicSiegeUniteLegale                       :string
#  nombrePeriodesUniteLegale                 :integer
#  nomenclatureActivitePrincipaleUniteLegale :string
#  nomUniteLegale                            :string
#  nomUsageUniteLegale                       :string
#  prenom1UniteLegale                        :string
#  prenom2UniteLegale                        :string
#  prenom3UniteLegale                        :string
#  prenom4UniteLegale                        :string
#  prenomUsuelUniteLegale                    :string
#  pseudonymeUniteLegale                     :string
#  sexeUniteLegale                           :string
#  sigleUniteLegale                          :string
#  siren                                     :string
#  societeMissionUniteLegale                 :string
#  statutDiffusionUniteLegale                :string
#  trancheEffectifsUniteLegale               :string
#  unitePurgeeUniteLegale                    :string
#  created_at                                :datetime         not null
#  updated_at                                :datetime         not null
#  tsvector_nom_tsearch                      :tsvector
#
# Indexes
#
#  index_unite_legales_on_siren                 (siren) UNIQUE
#  index_unite_legales_on_tsvector_nom_tsearch  (tsvector_nom_tsearch)
#

require "test_helper"

class UniteLegaleTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
