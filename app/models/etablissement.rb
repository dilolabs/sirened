# == Schema Information
#
# Table name: etablissements
#
#  id                                             :uuid             not null, primary key
#  activitePrincipaleEtablissement                :string
#  activitePrincipaleRegistreMetiersEtablissement :string
#  anneeEffectifsEtablissement                    :integer
#  caractereEmployeurEtablissement                :string
#  codeCedex2Etablissement                        :string
#  codeCedexEtablissement                         :string
#  codeCommune2Etablissement                      :string
#  codeCommuneEtablissement                       :string
#  codePaysEtranger2Etablissement                 :string
#  codePaysEtrangerEtablissement                  :string
#  codePostal2Etablissement                       :string
#  codePostalEtablissement                        :string
#  complementAdresse2Etablissement                :string
#  complementAdresseEtablissement                 :string
#  dateCreationEtablissement                      :date
#  dateDebut                                      :date
#  dateDernierTraitementEtablissement             :datetime
#  denominationUsuelleEtablissement               :string
#  distributionSpeciale2Etablissement             :string
#  distributionSpecialeEtablissement              :string
#  enseigne1Etablissement                         :string
#  enseigne2Etablissement                         :string
#  enseigne3Etablissement                         :string
#  etablissementSiege                             :string
#  etatAdministratifEtablissement                 :string
#  indiceRepetition2Etablissement                 :string
#  indiceRepetitionEtablissement                  :string
#  libelleCedex2Etablissement                     :string
#  libelleCedexEtablissement                      :string
#  libelleCommune2Etablissement                   :string
#  libelleCommuneEtablissement                    :string
#  libelleCommuneEtranger2Etablissement           :string
#  libelleCommuneEtrangerEtablissement            :string
#  libellePaysEtranger2Etablissement              :string
#  libellePaysEtrangerEtablissement               :string
#  libelleVoie2Etablissement                      :string
#  libelleVoieEtablissement                       :string
#  nic                                            :string
#  nombrePeriodesEtablissement                    :integer
#  nomenclatureActivitePrincipaleEtablissement    :string
#  numeroVoie2Etablissement                       :string
#  numeroVoieEtablissement                        :string
#  siren                                          :string
#  siret                                          :string
#  statutDiffusionEtablissement                   :string
#  trancheEffectifsEtablissement                  :string
#  typeVoie2Etablissement                         :string
#  typeVoieEtablissement                          :string
#  created_at                                     :datetime         not null
#  updated_at                                     :datetime         not null
#  unite_legale_id                                :uuid             not null
#
# Indexes
#
#  index_etablissements_on_siret            (siret) UNIQUE
#  index_etablissements_on_unite_legale_id  (unite_legale_id)
#
# Foreign Keys
#
#  fk_rails_...  (unite_legale_id => unite_legales.id)
#
class Etablissement < ApplicationRecord
  include Importable

  belongs_to :unite_legale

  validates :siret, presence: true, uniqueness: true
end
