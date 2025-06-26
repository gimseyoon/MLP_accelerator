/*
 * 2024 Gilhyeon Lee
 * gilhyeonlee@seoultech.ac.kr
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>
#include <string.h>
#pragma warning(disable : 4996)

 //To save the arrays as test files with one value per line.
void save_output_to_file(const char* filename, void* array, const char* element_size, size_t num_elements) {
    FILE* file = fopen(filename, "w");
    if (file == NULL) {
        printf("Error opening file %s\n", filename);
        return;
    }

    if (element_size == "int8_t") {
        int8_t* data = (int8_t*)array;
        for (size_t i = 0; i < num_elements; i++) {
            fprintf(file, "%d\n", data[i]);
        }
    }

    else if (element_size == "int32_t") {
        int32_t* data = (int32_t*)array;
        for (size_t i = 0; i < num_elements; i++) {
            fprintf(file, "%d\n", data[i]);
        }
    }

    else if (element_size == "float") {
        float* data = (float*)array;
        for (size_t i = 0; i < num_elements; i++) {
            int32_t int_data = (int32_t)data[i];
            fprintf(file, "%d\n", int_data);
        }
    }

    fclose(file);
}

// To load weights values from text files. (float)
int load_weights_from_file(const char* filename, int32_t** weights, size_t num_elements) {
    FILE* fp = fopen(filename, "r");
    if (!fp) {
        fprintf(stderr, "Error: failed to open file %s\n", filename);
        return -1;
    }
    for (size_t i = 0; i < num_elements; i++) {
        int32_t value;
        if (fscanf(fp, "%d", &value) != 1) {
            fprintf(stderr, "Error: failed to read file %s\n", filename);
            fclose(fp);
            return -1;
        }
        (*weights)[i] = (int32_t)value;
    }
    fclose(fp);
    return 0;
}

struct MLP {
    int32_t* weight_layer1;
    int32_t* weight_layer2;
    int32_t* weight_layer3;
    int32_t* weight_layer4;
    int32_t* weight_layer5;
};


int inference(const int32_t* input_image, struct MLP* model)
{
    // Define the input and output arrays
    int32_t input[784];
    int32_t layer1_output[64];
    int32_t layer2_output[32];
    int32_t layer3_output[32];
    int32_t layer4_output[16];
    int32_t output[10];
    int64_t layer_intermediate[784];

    //Normalize and 16-bit left shift
    for (int i = 0; i < 784; i++) {

        /*  Originally

            First, you have to normalize the input_image pixel values to the range [0, 1] by dividing each value by 255

            // intermediate_input[i] = (float)(input_image[i] / 255.0)         // To Normalize

            Second, and left shift the to represent fixed-point value

            // intermediate_input[i] = intermediate_input[i] * 65536           // Bit-shift and truncation to represent fixed-point


            But, For your convinience, we merged " /255.0 " with " * 65536 "  approximately
            by calculating it as below

            // input[i] = (input_image[i] / 255.0) * 65536  '=. input_image[i] * 256

        */

        input[i] = (input_image[i] / 255.0) * 65536;             // Merged code

    }
    //save_output_to_file("./save/normalized_shitfted_input.txt", input, "int32_t", 784);

    /*
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                            MLP First Layer ( Fully - connected Layer 1 )           784 -> 64
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    */
    // Perform the first layer of the MLP
    memset(layer_intermediate, 0, sizeof(layer_intermediate));
    for (int i = 0; i < 64; i++) {
        for (int j = 0; j < 784; j++) {
            layer_intermediate[i] += (int64_t)input[j] * model->weight_layer1[i * 784 + j];
        }
        layer1_output[i] = (int32_t)(layer_intermediate[i] >> 16);
    }
    //save_output_to_file("./save/layer1_output.txt", layer1_output, "int32_t", 64);

    // relu
    for (int i = 0; i < 64; i++) {
        if (layer1_output[i] < 0)  layer1_output[i] = 0;
    }

    /*
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                            MLP Second Layer ( Fully - connected Layer 2 )          64 -> 32
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    */
    // Perform the second layer of the MLP
    memset(layer_intermediate, 0, sizeof(layer_intermediate));
    for (int i = 0; i < 32; i++) {
        for (int j = 0; j < 64; j++) {
            layer_intermediate[i] += (int64_t)layer1_output[j] * model->weight_layer2[i * 64 + j];
        }
        layer2_output[i] = (int32_t)(layer_intermediate[i] >> 16);
    }
    //save_output_to_file("./save/layer2_output.txt", layer2_output, "int32_t", 32);

    // relu
    for (int i = 0; i < 32; i++) {
        if (layer2_output[i] < 0)  layer2_output[i] = 0;
    }

    /*
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                            MLP third Layer ( Fully - connected Layer 3 )           32-> 32
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    */
    // Perform the third layer of the MLP
    memset(layer_intermediate, 0, sizeof(layer_intermediate));
    for (int i = 0; i < 32; i++) {
        for (int j = 0; j < 32; j++) {
            layer_intermediate[i] += (int64_t)layer2_output[j] * model->weight_layer3[i * 32 + j];
        }
        layer3_output[i] = (int32_t)(layer_intermediate[i] >> 16);
    }
    //save_output_to_file("./save/layer3_output.txt", layer3_output, "int32_t", 32);

    // relu
    for (int i = 0; i < 32; i++) {
        if (layer3_output[i] < 0)  layer3_output[i] = 0;
    }

    /*
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                         MLP forth Layer ( Fully - connected Layer 4 )              32 -> 16
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    */
    // Perform the forth layer of the MLP
    memset(layer_intermediate, 0, sizeof(layer_intermediate));
    for (int i = 0; i < 16; i++) {
        for (int j = 0; j < 32; j++) {
            layer_intermediate[i] += (int64_t)layer3_output[j] * model->weight_layer4[i * 32 + j];
        }
        layer4_output[i] = (int32_t)(layer_intermediate[i] >> 16);
    }
    //save_output_to_file("./save/layer4_output.txt", layer4_output, "int32_t", 16);

    // relu
    for (int i = 0; i < 16; i++) {
        if (layer4_output[i] < 0)  layer4_output[i] = 0;
    }

    /*
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                                MLP output Layer ( Fully - connected Layer )            16 -> 10
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    */
    // Perform the fifth layer of the MLP
    memset(layer_intermediate, 0, sizeof(layer_intermediate));
    for (int i = 0; i < 10; i++) {
        for (int j = 0; j < 16; j++) {
            layer_intermediate[i] += (int64_t)layer4_output[j] * model->weight_layer5[i * 16 + j];
        }
        output[i] = (int32_t)(layer_intermediate[i] >> 16);
    }
    //save_output_to_file("./save/output.txt", output, "int32_t", 10);

    // Find the index of the maximum output value
    int max_index = 0;
    for (int i = 1; i < 10; i++) {
        if (output[i] > output[max_index]) {
            max_index = i;
        }
    }

    // Return the index of the maximum output value
    return max_index;
}

int main() {
    setbuf(stdout, NULL);

    // Initialize MLP structure
    struct MLP model;

    // Allocate memory for the weight matrix & Load the weights from file
    model.weight_layer1 = (int32_t*)malloc(64 * 784 * sizeof(int32_t));
    model.weight_layer2 = (int32_t*)malloc(32 * 64 * sizeof(int32_t));
    model.weight_layer3 = (int32_t*)malloc(32 * 32 * sizeof(int32_t));
    model.weight_layer4 = (int32_t*)malloc(16 * 32 * sizeof(int32_t));
    model.weight_layer5 = (int32_t*)malloc(10 * 16 * sizeof(int32_t));
    if (load_weights_from_file("C:/Digital_Circuit_Design_Project_ZIP/seoultech_MLP_accelerator/DSD24_Termprj_Provided_Materials/02_Provided_Data/4_ref_q1616_weight/fixed_point_W1_dec.txt", &model.weight_layer1, 64 * 784) != 0) { return -1; }
    if (load_weights_from_file("C:/Digital_Circuit_Design_Project_ZIP/seoultech_MLP_accelerator/DSD24_Termprj_Provided_Materials/02_Provided_Data/4_ref_q1616_weight/fixed_point_W2_dec.txt", &model.weight_layer2, 32 * 64) != 0) { return -1; }
    if (load_weights_from_file("C:/Digital_Circuit_Design_Project_ZIP/seoultech_MLP_accelerator/DSD24_Termprj_Provided_Materials/02_Provided_Data/4_ref_q1616_weight/fixed_point_W3_dec.txt", &model.weight_layer3, 32 * 32) != 0) { return -1; }
    if (load_weights_from_file("C:/Digital_Circuit_Design_Project_ZIP/seoultech_MLP_accelerator/DSD24_Termprj_Provided_Materials/02_Provided_Data/4_ref_q1616_weight/fixed_point_W4_dec.txt", &model.weight_layer4, 16 * 32) != 0) { return -1; }
    if (load_weights_from_file("C:/Digital_Circuit_Design_Project_ZIP/seoultech_MLP_accelerator/DSD24_Termprj_Provided_Materials/02_Provided_Data/4_ref_q1616_weight/fixed_point_W5_dec.txt", &model.weight_layer5, 10 * 16) != 0) { return -1; }

    /*
    Option 1. Inference for multiple input image.
        You can inference 1~9999 testdataset at once by adjusting "num_files" value.
        You can check the accuracy for test dataset.
    */

    const int num_files = 10;    // You can modify value by 1 ~ 9999 

    float accuracy = 0;
    int correct_count = 0;

    int y_label;
    char filename[100];
    for (int num = 1; num < num_files + 1; num++) {

        int found = 0;
        for (int label = 0; label <= 9 && !found; label++)
        {
            snprintf(filename, sizeof(filename), "C:/Digital_Circuit_Design_Project_ZIP/seoultech_MLP_accelerator/DSD24_Termprj_Provided_Materials/02_Provided_Data/2_ref_mnist_testset_txt_per_pixel/%d_label_%d.txt", num, label);

            FILE* file = fopen(filename, "r");

            if (file != NULL) {
                y_label = label;
                int32_t input_image[784];

                for (int i = 0; i < 784; i++) {
                    int value;
                    if (fscanf(file, "%d", &value) != 1) {
                        fprintf(stderr, "Error: failed to read file %s\n", filename);
                        fclose(file);
                        return -1;
                    }
                    input_image[i] = (int32_t)value;
                }

                int result = inference(input_image, &model);
                if (y_label == result) correct_count = correct_count + 1;
                printf("Input Data Path :'%s', label=%d, result=% d \n ", filename, y_label, result);
                fclose(file);
                break;
            }
        }

    }

    printf("correct_count = %d\n", correct_count);

    //// Calcurate the accuracy & Print
    accuracy = (float)correct_count / (float)num_files * 100;
    printf(" Accuracy : %.2f \n", accuracy);

    /*
    Option 2. Inference for single specific input image.
        You can get the intermediate value of specific input image.
    */

    //const char* filename = "./mnist_testset_txt_per_pixel/1_label_2.txt";
    //int y_label;    // the true label for the specific image
    //sscanf(strrchr(filename, '_') + 1, "%d", &y_label);
    //int32_t input_image[784];

    //FILE* file = fopen(filename, "r");

    //if (file != NULL) {
    //    for (size_t i = 0; i < 784; i++) {
    //        int value;
    //        if (fscanf(file, "%d", &value) != 1) {
    //            fprintf(stderr, "error: failed to read file %s\n", filename);
    //            fclose(file);
    //            return -1;
    //        }
    //        input_image[i] = (int32_t)value;
    //    }

    //    int result = inference(input_image, &model);
    //    //int result = inference(input_image, &model);

    //    printf("input data path: '%s', label=%d, result=%d\n", filename, y_label, result);
    //    fclose(file);
    //}
    //else {
    //    fprintf(stderr, "error: failed to open file %s\n", filename);
    //}

    //--------------------------------------------------------------------------------------------------------------------------------

    return 0;
}


