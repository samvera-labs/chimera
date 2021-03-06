# frozen_string_literal: true

module Hyrax

  class DataSetForm < DeepblueForm

    self.model_class = ::DataSet

    self.terms -= %i[ rights_statement ]
    self.terms +=
      %i[
        authoremail
        date_coverage
        description
        fundedby
        fundedby_other
        doi
        grantnumber
        keyword
        methodology
        referenced_by
        rights_license
        rights_license_other
        subject_discipline
        curation_notes_admin
        curation_notes_user
      ]

    self.default_work_primary_terms =
      %i[
        title
        creator
        authoremail
        methodology
        description
        date_coverage
        rights_license
        rights_license_other
        subject_discipline
        fundedby
        fundedby_other
        grantnumber
        keyword
        language
        referenced_by
        curation_notes_admin
        curation_notes_user
      ]

    self.default_work_secondary_terms = []

    self.required_fields =
      %i[
        title
        creator
        authoremail
        methodology
        description
        rights_license
        subject_discipline
      ]

    def data_set?
      true
    end

    def merge_date_coverage_attributes!(hsh)
      @attributes.merge!(hsh&.stringify_keys || {})
    end

  end

end
