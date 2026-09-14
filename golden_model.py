def golden_model(input_data, weight, bias):
    output_rows = len(input_data)
    input_cols = len(input_data[0])
    output_cols = len(weight[0])

    output_matrix = [[0 for _ in range(output_cols)] for _ in range(output_rows)]

    for i in range(output_rows):
        for j in range(output_cols):
            dot_product = 0

            for k in range(input_cols):
                dot_product += input_data[i][k] * weight[k][j]

            result = dot_product + bias[j]
            output_matrix[i][j] = max(0, result)

    return output_matrix