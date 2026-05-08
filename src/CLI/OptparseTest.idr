module CLI.OptparseTest
import Options.Applicative.Types
import Options.Applicative.Run

testParser : Parser String
testParser =
  pure "optparse works!"
