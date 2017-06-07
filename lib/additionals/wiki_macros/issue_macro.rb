# Issue wiki macros
module Additionals
  module WikiMacros
    Redmine::WikiFormatting::Macros.register do
      desc  <<-EOHELP
  Create a link to issue with the subject of this issue.
       Syntax:

       {{issue(ID [, format=USER_FORMAT)}}
       ID is issue id
       USER_FORMATS
       - text
       - short
       - link (default)
       - full

       Examples:

       {{issue(1)}}
       ...Link to issue with subject and id
       {{issue(1, format=short)}}
       ...Link to issue with subject (without id)
       {{issue(1, format=text)}}
       ...Display subject name
       {{issue(1, format=full)}}
       ...Link to issue with track, issue id and subject
   EOHELP

      macro :issue do |_obj, args|
        args, options = extract_macro_options(args, :format)
        raise 'The correct usage is {{issue(<issue_id>, format=FORMAT)}}' if args.empty?
        issue_id = args[0]

        issue = Issue.find_by(id: issue_id)
        return 'N/A' if issue.nil? || !issue.visible?

        text = case options[:format]
               when 'full'
                 "#{issue.tracker.name} ##{issue.id} #{issue.subject}"
               when 'text', 'short'
                 issue.subject
               else
                 "#{issue.subject} ##{issue.id}"
               end

        if options[:format].blank? || options[:format] != 'text'
          link_to(text, issue_url(issue, only_path: true), class: issue.css_classes)
        else
          text
        end
      end
    end
  end
end
