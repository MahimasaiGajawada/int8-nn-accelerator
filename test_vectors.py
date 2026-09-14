import random

def test_vectors():
    random.seed(128)

    test_vectors = []

    for test_num in range(100):

        input_values = [
            random.randint(-128, 127)
            for _ in range(4)
        ]

        weight_values = [
            random.randint(-128, 127)
            for _ in range(6)
        ]

        bias_values = [
            random.randint(-128, 127)
            for _ in range(3)
        ]

        name = f"Random Test #{test_num + 1}"
        test_vectors.append({
                "name": name,
                "input_values": input_values,
                "weight_values": weight_values,
                "bias_values": bias_values
                })

    return test_vectors

if __name__ == "__main__":
    vectors = test_vectors()
    print(len(vectors))
    print(vectors[0])
