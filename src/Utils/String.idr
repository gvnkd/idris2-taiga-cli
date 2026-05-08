module Utils.String
import Data.Bits
import Data.List
import Data.String

export
tail : String -> String
tail "" =
  ""
tail str =
  assert_total (strTail str)

export
splitBy : Char -> String -> (String, String)
splitBy sep =
  mapSnd tail . break (== sep)

utf8_bytelen : Bits8 -> Maybe (Bits8, Nat)
utf8_bytelen x =
  if (x .&. 127) == x
    then Just (x, 0)
    else
      if (shiftR x 5) == 6
        then Just (x .&. 31, 1)
          else
            if (shiftR x 4) == 14
              then Just (x .&. 15, 2)
                else
                  if (shiftR x 3) == 30 then Just (x .&. 7, 3) else Nothing
-- ascii
utf8_unmask : Bits8 -> Maybe Bits8
utf8_unmask x =
  const (x .&. 63) <$> guard (shiftR x 6 == 2)

utf8_pushbits : Integer -> List Bits8 -> Integer
utf8_pushbits acc [] =
  acc
utf8_pushbits acc (x :: xs) =
  utf8_pushbits ((shiftL acc 6) .|. (cast x)) xs

public export
utf8_pack : List Bits8 -> Maybe String
utf8_pack =
  go []
  where
    go : List Char -> List Bits8 -> Maybe String
    go acc [] =
      Just $ pack $ reverse acc
    go acc (x :: xs) = do
      (x, l) <- utf8_bytelen x
      let (y, ys) = splitAt l xs
      guard (length y == l)
      y <- traverse utf8_unmask y
      let c : _ = utf8_pushbits (cast x) y
      go ((cast c) :: acc) ys

utf8_char_bytelen : Integer -> (Nat, Bits8)
utf8_char_bytelen x =
  if x <= 127
    then (0, 0)
    else
      if x <= 2047 then (1, 192) else if x <= 65535 then (2, 224) else (3, 240)

utf8_encode : Integer -> List Bits8
utf8_encode i =
  case utf8_char_bytelen i of
    (0, _) => [cast i]
    (n, m) => loop [] i n m
  where
    loop : List Bits8 -> Integer -> Nat -> Bits8 -> List Bits8
    loop acc i Z mask =
      (cast i .|. mask) :: acc
    loop acc i (S n) mask =
      let b = cast (i .&. 63) .|. 128 in let i' = shiftR i 6 in loop (b :: acc) i' n mask

public export
utf8_unpack : String -> List Bits8
utf8_unpack str =
  unpack str >>= utf8_encode . cast
