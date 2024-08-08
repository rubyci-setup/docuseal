# frozen_string_literal: true

module Api
  class ToolsController < ApiBaseController
    skip_authorization_check

    def merge
      files = params[:files] || []

      return render json: { error: 'Files are required' }, status: :unprocessable_entity if files.blank?
      return render json: { error: 'At least 2 files are required' }, status: :unprocessable_entity if files.size < 2

      render json: {
        data: Base64.encode64(PdfUtils.merge(files.map { |base64| StringIO.new(Base64.decode64(base64)) }).string)
      }
    end

    def verify
      file = Base64.decode64(params[:file])
      pdf = HexaPDF::Document.new(io: StringIO.new(file))

      trusted_certs = Accounts.load_trusted_certs(current_account)

      is_checksum_found = ActiveStorage::Attachment.joins(:blob)
                                                   .where(name: 'documents', record_type: 'Submitter')
                                                   .exists?(blob: { checksum: Digest::MD5.base64digest(file) })

      render json: {
        checksum_status: is_checksum_found ? 'verified' : 'not_found',
        signatures: pdf.signatures.map do |sig|
          {
            verification_result: sig.verify(trusted_certs:).messages,
            signer_name: sig.signer_name,
            signing_reason: sig.signing_reason,
            signing_time: sig.signing_time,
            signature_type: sig.signature_type
          }
        end
      }
    end
  end
end