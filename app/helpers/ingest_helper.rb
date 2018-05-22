# frozen_string_literal: true
#
module IngestHelper

  # @param [FileSet] file_set
  # @param [String] repository_file_id identifier for a Hydra::PCDM::File
  # @param [String, NilClass] file_path the cached file within the Hyrax.config.working_path
  def self.characterize( file_set,
                         repository_file_id,
                         file_path = nil,
                         delete_input_file: true,
                         continue_job_chain: true,
                         continue_job_chain_later: true )
    # # See Hyrax gem: app/job/characterize_job.rb
    # # def perform(file_set, file_id, filepath = nil)
    # raise "#{file_set.class.characterization_proxy} was not found for FileSet #{file_set.id}" unless file_set.characterization_proxy?
    # filepath = Hyrax::WorkingDirectory.find_or_retrieve(file_id, file_set.id) unless filepath && File.exist?(filepath)
    # Hydra::Works::CharacterizationService.run(file_set.characterization_proxy, filepath)
    # Rails.logger.debug "Ran characterization on #{file_set.characterization_proxy.id} (#{file_set.characterization_proxy.mime_type})"
    # file_set.characterization_proxy.save!
    # file_set.update_index
    # file_set.parent.in_collections.each(&:update_index) if file_set.parent
    # CreateDerivativesJob.perform_later(file_set, file_id, filepath)

    file_name = Hyrax::WorkingDirectory.find_or_retrieve( repository_file_id, file_set.id, file_path )
    file_ext = File.extname file_set.label
    if DeepBlueDocs::Application.config.characterize_excluded_ext_set.has_key? file_ext
      Rails.logger.info "Skipping characterization of file with extension #{file_ext}: #{file_name}"
      perform_create_derivatives_job( file_set,
                                      repository_file_id,
                                      file_name,
                                      file_path,
                                      delete_input_file: delete_input_file,
                                      continue_job_chain: continue_job_chain,
                                      continue_job_chain_later: continue_job_chain_later )
      return
    end
    unless file_set.characterization_proxy?
      error_msg = "#{file_set.class.characterization_proxy} was not found"
      Rails.logger.error error_msg
      raise LoadError, error_msg
    end
    begin
      proxy = file_set.characterization_proxy
      Hydra::Works::CharacterizationService.run( proxy, file_name )
      Rails.logger.debug "Ran characterization on #{proxy.id} (#{proxy.mime_type})"
      file_set.characterization_proxy.save!
      file_set.update_index
      file_set.parent.in_collections.each(&:update_index) if file_set.parent
    rescue Exception => e
      Rails.logger.error "TaskIngestHelper.create_derivatives(#{file_name}) #{e.class}: #{e.message} at #{e.backtrace[0]}"
    ensure
      perform_create_derivatives_job( file_set,
                                      repository_file_id,
                                      file_name,
                                      file_path,
                                      delete_input_file: delete_input_file,
                                      continue_job_chain: continue_job_chain,
                                      continue_job_chain_later: continue_job_chain_later )
    end
  end

  # @param [FileSet] file_set
  # @param [String] repository_file_id identifier for a Hydra::PCDM::File
  # @param [String, NilClass] file_path the cached file within the Hyrax.config.working_path
  def self.create_derivatives( file_set, repository_file_id, file_path = nil, delete_input_file: true )
    # # See Hyrax gem: app/job/create_derivatives_job.rb
    # # def perform(file_set, file_id, filepath = nil)
    # return if file_set.video? && !Hyrax.config.enable_ffmpeg
    # filename = Hyrax::WorkingDirectory.find_or_retrieve(file_id, file_set.id, filepath)
    #
    # file_set.create_derivatives(filename)
    #
    # # Reload from Fedora and reindex for thumbnail and extracted text
    # file_set.reload
    # file_set.update_index
    # file_set.parent.update_index if parent_needs_reindex?(file_set)

    file_name = Hyrax::WorkingDirectory.find_or_retrieve( repository_file_id, file_set.id, file_path )
    Rails.logger.warn "Create derivatives for: #{file_name}."
    begin
      file_ext = File.extname file_set.label
      if DeepBlueDocs::Application.config.derivative_excluded_ext_set.has_key? file_ext
        Rails.logger.info "Skipping derivative of file with extension #{file_ext}: #{file_name}"
        return
      end
      if file_set.video? && !Hyrax.config.enable_ffmpeg
        Rails.logger.info "Skipping video derivative job for file: #{file_name}"
        return
      end
      threshold_file_size = DeepBlueDocs::Application.config.derivative_max_file_size
      if threshold_file_size > -1 && File.exist?(file_name) && File.size(file_name) > threshold_file_size
        human_readable = ActiveSupport::NumberHelper::NumberToHumanSizeConverter.convert( threshold_file_size, precision: 3 )
        Rails.logger.info "Skipping file larger than #{human_readable} for create derivative job file: #{file_name}"
        return
      end
      Rails.logger.debug "About to call create derivatives: #{file_name}."
      file_set.create_derivatives(file_name)
      Rails.logger.debug "Create derivatives successful: #{file_name}."
      # Reload from Fedora and reindex for thumbnail and extracted text
      file_set.reload
      file_set.update_index
      file_set.parent.update_index if parent_needs_reindex?(file_set)
      Rails.logger.debug "Successful create derivative job for file: #{file_name}"
        #delete_file( file_path, delete_file_flag: delete_input_file, msg_prefix: 'Create derivatives ' )
    rescue Exception => e
      Rails.logger.error "TaskIngestHelper.create_derivatives(#{file_set},#{repository_file_id},#{file_path}) #{e.class}: #{e.message} at #{e.backtrace[0]}"
    ensure
      #This is the last step in the process ( ingest job -> characterization job -> create derivative (last step))
      #So now it's safe to remove the file uploaded file.
      delete_file( file_path, delete_file_flag: delete_input_file, msg_prefix: 'Create derivatives ' )
    end
  end

  def self.delete_file( file_path, delete_file_flag: false, msg_prefix: '' )
    if delete_file_flag
      if File.exist? file_path
        File.delete file_path
        Rails.logger.debug "#{msg_prefix}file deleted: #{file_path}"
      end
    end
  end

  # @param [FileSet] file_set
  # @param [String] filepath the cached file within the Hyrax.config.working_path
  # @param [User] user
  # @option opts [String] mime_type
  # @option opts [String] filename
  # @option opts [String] relation, ex. :original_file
  def self.ingest( file_set, path, user, opts = {} )
    # launched from Hyrax gem: app/actors/hyrax/actors/file_set_actor.rb  FileSetActor#create_content
    # See Hyrax gem: app/job/ingest_local_file_job.rb
    # def perform(file_set, path, user)
    file_set.label ||= File.basename(path)
    file_set_actor_create_content( file_set, File.open(path) )

    # actor = Hyrax::Actors::FileSetActor.new(file_set, user)
    #
    # if actor.create_content(File.open(path))
    #   #Hyrax.config.callback.run(:after_import_local_file_success, file_set, user, path)
    #   #Rails.logger.info "create content succeeded"
    # else
    #   #Hyrax.config.callback.run(:after_import_local_file_failure, file_set, user, path)
    #   Rails.logger.error "create content failed"
    # end
  end

  def self.file_set_actor_create_content( file_set, file, relation = :original_file )
    # If the file set doesn't have a title or label assigned, set a default.
    #file_set.label ||= label_for(file)
    file_set.title = [file_set.label] if file_set.title.blank?
    return false unless file_set.save # Need to save to get an id
    # if from_url
    #   # If ingesting from URL, don't spawn an IngestJob; instead
    #   # reach into the FileActor and run the ingest with the file instance in
    #   # hand. Do this because we don't have the underlying UploadedFile instance
    #   file_actor = build_file_actor(relation)
    #   file_actor.ingest_file(wrapper!(file: file, relation: relation))
    #   # Copy visibility and permissions from parent (work) to
    #   # FileSets even if they come in from BrowseEverything
    #   VisibilityCopyJob.perform_later(file_set.parent)
    #   InheritPermissionsJob.perform_later(file_set.parent)
    # else
    #   IngestJob.perform_later(wrapper!(file: file, relation: relation))
    # end
    io = JobIoWrapper.create_with_varied_file_handling!(user: user, file: file, relation: relation, file_set: file_set)
    # FileActor#ingest_file(io)
    # def ingest_file(io)
    # Skip versioning because versions will be minted by VersionCommitter as necessary during save_characterize_and_record_committer.
    Hydra::Works::AddFileToFileSet.call( file_set,
                                        io,
                                        relation,
                                        versioning: false )
    return false unless file_set.save
    repository_file = related_file( file_set, relation )
    Hyrax::VersioningService.create(repository_file, user)
    #pathhint = io.uploaded_file.uploader.path if io.uploaded_file # in case next worker is on same filesystem
    #CharacterizeJob.perform_later(file_set, repository_file.id, pathhint || io.path)
    characterize( file_set, repository_file.id, io.path )
  end

  def self.related_file( file_set, relation )
    file_set.public_send(relation) || raise("No #{relation} returned for FileSet #{file_set.id}")
  end

  # If this file_set is the thumbnail for the parent work,
  # then the parent also needs to be reindexed.
  def self.parent_needs_reindex?(file_set)
    return false unless file_set.parent
    file_set.parent.thumbnail_id == file_set.id
  end

  def self.perform_create_derivatives_job( file_set,
                                           repository_file_id,
                                           file_name,
                                           file_path,
                                           delete_input_file: true,
                                           continue_job_chain: true,
                                           continue_job_chain_later: true )
    if continue_job_chain
      if continue_job_chain_later
        CreateDerivativesJob.perform_later( file_set, repository_file_id, file_name, delete_input_file )
      else
        #CreateDerivativesJob.perform_now( file_set, repository_file_id, file_name, delete_input_file )
        create_derivatives( file_set, repository_file_id, file_name, delete_input_file )
      end
    else
      delete_file( file_path, delete_file_flag: delete_input_file, msg_prefix: 'Characterize ' )
    end
  end

  def self.update_total_file_size( file_set, log_prefix: nil )
    Rails.logger.info "begin TaskIngestHelper.update_total_file_size"
    Rails.logger.debug "#{log_prefix} file_set.orginal_file.size=#{file_set.original_file.size}" unless log_prefix.nil?
    return if file_set.parent.nil?
    total = file_set.parent.total_file_size
    if total.nil? || 0 == total
      Rails.logger.debug "#{log_prefix}.file_set.parent.update_total_file_size!" unless log_prefix.nil?
      file_set.parent.update_total_file_size!
    else
      Rails.logger.debug "#{log_prefix}.file_set.parent.total_file_size_add_file_set!" unless log_prefix.nil?
      file_set.parent.total_file_size_add_file_set! file_set
    end
    Rails.logger.info "end TaskIngestHelper.update_total_file_size"
  rescue Exception => e
    Rails.logger.error "TaskIngestHelper.update_total_file_size(#{file_set}) #{e.class}: #{e.message} at #{e.backtrace[0]}"
  end

end