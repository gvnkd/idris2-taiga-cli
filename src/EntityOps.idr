||| Tag identifying which entity type an operations bundle handles.
module EntityOps

import Data.Bits
import Taiga.Env
import Model.Common

%language ElabReflection

public export
data EntityType = TaskE | EpicE | StoryE | IssueE | WikiE | MilestoneE
