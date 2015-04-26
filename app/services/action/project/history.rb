require 'inch_ci/action'
require 'inch_ci/grade_list_collection'

module Action
  module Project
    class History < Show
      include InchCI::Action
      include Action::SetProjectAndBranch

      exposes :project, :branch, :revision, :collection, :suggestion_count
      exposes :diffs, :code_object_map

      def initialize(params)
        super
        if @revision
          @builds = find_builds

          revision_diffs = InchCI::Store::FindRevisionDiffs.call(@branch.to_model)
          @diffs = limit present(revision_diffs, RevisionDiffPresenter)

          @code_object_map = {}
          code_object_ids = @diffs.flat_map do |diff|
            diff.to_model.code_object_diffs.flat_map do |odiff|
              [odiff.before_object_id, odiff.after_object_id]
            end
          end
          ::CodeObject.where(:id => code_object_ids).each do |code_object|
            @code_object_map[code_object.id] = CodeObjectPresenter.new(code_object)
          end

          @builds = present(@builds, BuildPresenter)
        end
      end

      private

      def find_builds
        InchCI::Store::FindBuildsInProject.call(@project)
      end

      def present(list, presenter_class)
        list.map { |diff| presenter_class.new(diff) }
      end

      def limit(list, max_count = 50)
        count = 0
        result = []
        list.each do |rev_diff|
          count += 1 if rev_diff.change_count > 0
          result << rev_diff
          if count >= max_count
            return result
          end
        end
        result
      end
    end
  end
end
