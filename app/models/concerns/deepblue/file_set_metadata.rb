# frozen_string_literal: true

module Deepblue
  module FileSetMetadata
    extend ActiveSupport::Concern

    included do

      property :curation_notes_admin, predicate: ::RDF::URI.new('https://deepblue.lib.umich.edu/data/help.help#curation_notes_admin'), multiple: true do |index|
        index.type :text
        index.as :stored_searchable
      end

      property :curation_notes_admin_ordered, predicate: ::RDF::URI.new('https://deepblue.lib.umich.edu/data/help.help#curation_notes_admin_ordered'), multiple: true do |index|
        index.type :text
        index.as :stored_searchable
      end

      property :curation_notes_user, predicate: ::RDF::URI.new('https://deepblue.lib.umich.edu/data/help.help#curation_notes_user'), multiple: true do |index|
        index.type :text
        index.as :stored_searchable
      end

      property :curation_notes_user_ordered, predicate: ::RDF::URI.new('https://deepblue.lib.umich.edu/data/help.help#curation_notes_user_ordered'), multiple: true do |index|
        index.type :text
        index.as :stored_searchable
      end

      property :file_size, predicate: ::RDF::Vocab::DC.SizeOrDuration, multiple: false

      property :prior_identifier, predicate: ActiveFedora::RDF::Fcrepo::Model.altIds, multiple: true do |index|
        index.as :stored_searchable
      end

      # TODO: can't use the same predicate twice
      # property :total_file_size_human_readable, predicate: ::RDF::Vocab::DC.SizeOrDuration, multiple: false

    end

  end
end
