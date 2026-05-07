||| Quick verification that optparse-applicative library is available and functional.
module CLI.OptparseTest

import Options.Applicative.Types
import Options.Applicative.Run

||| Dummy parser to verify compilation works with optparse types.
testParser : Parser String
testParser = pure "optparse works!"
