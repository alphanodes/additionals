# frozen_string_literal: true

module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc <<-DESCRIPTION
  Create a link to issue with the subject of this issue.

  Syntax:

     {{issue(URL [, format=USER_FORMAT, id=ID, note_id=NOTE_ID)}}
     URL is URL to issue
     USER_FORMATS
     - text
     - short
     - link (default)
     - full
     ID is issue
     NOTE_ID is note id, if you want to display it

  Examples:

     {{issue(1)}}
     ...Link to issue with id and subject
     {{issue(http://myredmine.url/issues/1)}}
     ...Link to issue with id and subject
     {{issue(http://myredmine.url/issues/1#note-3)}}
     ...Link to issue with id and subject and display comment 3
     {{issue(1, format=short)}}
     ...Link to issue with subject (without id)
     {{issue(1, format=text)}}
     ...Display subject name
     {{issue(1, format=full)}}
     ...Link to issue with track, issue id and subject
      DESCRIPTION

      macro :issue do |_obj, args|
        args, options = extract_macro_options args, :id, :note_id, :format
        raise 'The correct usage is {{issue(<url>, format=FORMAT, id=INT, note_id=INT)}}' if args.empty? && options[:id].blank?

        comment_id = options[:note_id].to_i if options[:note_id].present?
        issue_id = options[:id].presence ||
                   (info = parse_issue_url args[0], comment_id
                    comment_id = info[:comment_id] if comment_id.nil?
                    info[:issue_id])

        issue = Issue.find_by id: issue_id
        return if issue.nil? || !issue.visible?

        text = case options[:format]
               when 'full'
                 "#{issue.tracker.name} ##{issue_id} #{issue.subject}"
               when 'text', 'short'
                 issue.subject
               else
                 "##{issue_id} #{issue.subject}"
               end

        if options[:format].blank? || options[:format] != 'text'
          render_issue_macro_link issue, text, comment_id
        else
          text
        end
      end
    end
  end
end
