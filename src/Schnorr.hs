module Schnorr
  ( Challenge
  , Response
  , PublicCommitment
  , PrivateCommitment
  , generateCommitment
  , computeResponse
  , verify
  ) where

import           Crypto.Hash
import           Crypto.Number.Generate     (generateBetween)
import           Crypto.Random.Types (MonadRandom)
import           Crypto.Number.Serialize    (os2ip)
import qualified Crypto.PubKey.ECC.ECDSA    as ECDSA
import qualified Crypto.PubKey.ECC.Generate as ECC
import qualified Crypto.PubKey.ECC.Prim     as ECC
import qualified Crypto.PubKey.ECC.Types    as ECC
import qualified Data.ByteString            as BS
import           Data.Monoid
import           Protolude

import qualified Curve

-----------------------------------------------------
-- Schnorr Indentification Scheme - Elliptic Curve
-----------------------------------------------------

type Challenge = Integer
type Response = Integer
type PublicCommitment = ECC.Point
type PrivateCommitment = Integer

-- | Compute response from previous generated values:
-- private commitment value, prover's private key and verifier's challenge
computeResponse
  :: Curve.Curve c
  => c
  -> PrivateCommitment
  -> ECDSA.PrivateKey
  -> Challenge
  -> Response
computeResponse curveName pc pk challenge =
  pc - ECDSA.private_d pk * challenge `mod` Curve.n curveName

-- | Verify proof given by the prover.
-- It receives a public key, a commitment, a challenge and a response value.
verify
  :: Curve.Curve c
  => c
  -> ECDSA.PublicKey
  -> PublicCommitment
  -> Challenge
  -> Response
  -> Bool
verify curveName pubKey pubCommit challenge r =
  verifyPubKey && verifyPubCommit
  where
    validPoint = Curve.isPointValid curveName (ECDSA.public_q pubKey)
    infinity = Curve.isPointAtInfinity curveName $
      Curve.pointMul curveName h (ECDSA.public_q pubKey)
    verifyPubKey = validPoint && not infinity
    t = Curve.pointAddTwoMuls curveName r g challenge (ECDSA.public_q pubKey)
    verifyPubCommit = pubCommit == t
    curve = Curve.curve curveName
    g = Curve.g curveName
    h = Curve.h curveName

-- | Generate random commitment value
-- The prover keeps the random value generated safe
-- while sharing the point in the curve obtained by multiplying G * [k]
generateCommitment
  :: (MonadRandom m, Curve.Curve c)
  => c
  -> m (PublicCommitment, PrivateCommitment)
generateCommitment curveName = do
  k <- generateBetween 0 (Curve.n curveName - 1)
  let k' = Curve.pointBaseMul curveName k
  pure (k', k)
