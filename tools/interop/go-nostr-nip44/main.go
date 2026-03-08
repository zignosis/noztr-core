package main

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/nbd-wtf/go-nostr/nip44"
)

type fixtureSet struct {
	SetID    string    `json:"set_id"`
	Fixtures []fixture `json:"fixtures"`
}

type fixture struct {
	ID        string `json:"id"`
	KeyHex    string `json:"conversation_key_hex"`
	NonceHex  string `json:"nonce_hex"`
	Plaintext string `json:"plaintext"`
	Payload   string `json:"payload_expectation_base64"`
}

func loadFixtures(path string) (fixtureSet, error) {
	bytes, err := os.ReadFile(path)
	if err != nil {
		return fixtureSet{}, err
	}

	var set fixtureSet
	if err := json.Unmarshal(bytes, &set); err != nil {
		return fixtureSet{}, err
	}
	return set, nil
}

func main() {
	fixturePath := filepath.Join("..", "fixtures", "nip44_ut_e_003.json")
	set, err := loadFixtures(fixturePath)
	if err != nil {
		fmt.Printf("RESULT FAIL: fixture load error: %v\n", err)
		os.Exit(1)
	}

	failures := 0
	fmt.Printf("go-nostr/nip44 replay set: %s\n", set.SetID)

	for _, fx := range set.Fixtures {
		keyBytes, err := hex.DecodeString(fx.KeyHex)
		if err != nil {
			failures++
			fmt.Printf("%s FAIL key hex decode: %v\n", fx.ID, err)
			continue
		}
		if len(keyBytes) != 32 {
			failures++
			fmt.Printf("%s FAIL key length: got %d want 32\n", fx.ID, len(keyBytes))
			continue
		}

		nonceBytes, err := hex.DecodeString(fx.NonceHex)
		if err != nil {
			failures++
			fmt.Printf("%s FAIL nonce hex decode: %v\n", fx.ID, err)
			continue
		}
		if len(nonceBytes) != 32 {
			failures++
			fmt.Printf("%s FAIL nonce length: got %d want 32\n", fx.ID, len(nonceBytes))
			continue
		}

		var key [32]byte
		copy(key[:], keyBytes)

		decrypted, err := nip44.Decrypt(fx.Payload, key)
		if err != nil {
			failures++
			fmt.Printf("%s FAIL decrypt error: %v\n", fx.ID, err)
			continue
		}
		if decrypted != fx.Plaintext {
			failures++
			fmt.Printf("%s FAIL decrypt mismatch\n", fx.ID)
			fmt.Printf("  got : %q\n", decrypted)
			fmt.Printf("  want: %q\n", fx.Plaintext)
			continue
		}

		encrypted, err := nip44.Encrypt(fx.Plaintext, key, nip44.WithCustomNonce(nonceBytes))
		if err != nil {
			failures++
			fmt.Printf("%s FAIL encrypt error: %v\n", fx.ID, err)
			continue
		}
		if encrypted != fx.Payload {
			failures++
			fmt.Printf("%s FAIL encrypt mismatch\n", fx.ID)
			fmt.Printf("  got : %s\n", encrypted)
			fmt.Printf("  want: %s\n", fx.Payload)
			continue
		}

		fmt.Printf("%s PASS decrypt+encrypt parity\n", fx.ID)
	}

	total := len(set.Fixtures)
	passed := total - failures
	if failures > 0 {
		fmt.Printf("RESULT FAIL: %d/%d fixtures passed\n", passed, total)
		os.Exit(1)
	}

	fmt.Printf("RESULT PASS: %d/%d fixtures\n", passed, total)
}
