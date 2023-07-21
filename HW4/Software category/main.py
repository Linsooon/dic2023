### Package Version
# numpy : 1.22.4
# PIL : 8.4.0

from PIL import Image
import PIL
import numpy as np
from numpy import asarray

import argparse

### functions
## Layer0
# convolution
def convolution2d(image, kernel, stride, padding, bias):
    image = np.pad(image, [(padding, padding), (padding, padding)], mode='edge')

    kernel_height, kernel_width = kernel.shape
    padded_height, padded_width = image.shape

    output_height = (padded_height - kernel_height) // stride + 1
    output_width = (padded_width - kernel_width) // stride + 1

    new_image = np.zeros((output_height, output_width)).astype(np.float32)

    for y in range(0, output_height):
        for x in range(0, output_width):
            new_image[y][x] = np.sum(image[y * stride : y * stride + kernel_height, x * stride:x * stride + kernel_width] * kernel).astype(np.float32)
    
    new_image = new_image + bias # which value of bias
    return new_image
    
# relu with/out rounding
def relu(image):
  output_height, output_width = image.shape
  for y in range(0, output_height):
    for x in range(0, output_width):
      if(image[y][x] <= 0): image[y][x] = 0
      #else: conv_img[y][x] = np.round(conv_img[y][x]) # use and TA's resized_gray pic np.round can get value as TA's pic(Layer0)
  return image
  
## Layer1
# maxpooling
def maxpooling2d(image, kernelSize, stride, padding):
  # image = np.pad(image, [(padding, padding), (padding, padding)], mode='edge')

  output_height = (image.shape[0] - kernelSize) // stride +1
  output_width = (image.shape[1] - kernelSize) // stride +1
  
  new_image = np.zeros((output_height, output_width)).astype(np.float32)
  for y in range(0, output_height):
    for x in range(0, output_width):
      max_of_pool = image[y * stride : y * stride + kernelSize, x * stride:x * stride + kernelSize].max() 
      # condition_is_true if condition else condition_is_false
      #new_image[y][x] = max_of_pool if isinstance(max_of_pool, int) else (int(max_of_pool)+1) # roundup : int()+1
      # check integer or not.
      if(str(max_of_pool)[-2:] == ".0"):
        new_image[y][x] = max_of_pool
      else:
        new_image[y][x] = int(max_of_pool)+1 # roundup : int()+1
  return new_image
 
## Format transform
# input should be float points
# from GeeksforGeeks with modified => https://www.geeksforgeeks.org/python-program-to-convert-floating-to-binary/
# Function converts the value passed as
# parameter to it's decimal representation
def decimal_converter(num):
    while num > 1:
        num /= 10
    return num

# Function returns octal representation
def format_transfom(number, places = 4):   ## def float_bin(number, places = 4):
    if(number >= 0): # Sign bit
      res = '0' 
    else:
      res = '1'

    # split() separates whole number and decimal
    # part and stores it in two separate variables
    whole, dec = str(number).split(".")
 
    # Convert both whole number and decimal 
    # part from string type to integer type
    whole = int(whole)
    
    # padding zeros in front
    converted_len = len(bin(whole).lstrip("0b"))
    if(converted_len < 8):
      res += '0' * (8 - converted_len)

    # Convert the whole number part to it's
    # respective binary form and remove the
    # "0b" from it.
    res += bin(whole).lstrip("0b") # + "."

    # leading zero in dec e.g. 0.0625
    if(dec == '0625'):
      places = places - 3
      res += '0' * 3

    dec = int(dec)

    if(dec != 0): # handle integer values
      # Iterate the number of times, we want
      # the number of decimal places to be
      for x in range(places):
  
          # Multiply the decimal value by 2
          # and separate the whole number part
          # and decimal part
          if(dec != 0): # to avoid enouter 0 and raise exception
            whole, dec = str((decimal_converter(dec)) * 2).split(".")
            # Convert the decimal part
            # to integer again
            dec = int(dec)
          else:
            whole = '0'
          # Keep adding the integer parts
          # receive to the result variable
          res += whole
    else:
      res += 4*'0'
    return res

## File saving 
def file_save(data, file_name = "img.dat", mode = "w"):
    str_list = []
    fp = open(file_name, "w")
    output_height, output_width = data.shape
    for y in range(0, output_height):
      for x in range(0, output_width):
        #print(data[y][x])
        str_list.append(format_transfom(data[y][x]))# cant handle integer
        str_list.append(" //data ")
        str_list.append(str(y*64+x) + ": " + str(data[y][x]))
        str_list.append("\n")
    # 將 lines 所有內容寫入到檔案
    fp.writelines(str_list)
    # 關閉檔案
    fp.close()

def parse_args():
    parser = argparse.ArgumentParser(description='input a square img and output a format for dic_hw4')
    parser.add_argument("input_img", help= 'path to jpg/png')
    parser.add_argument('--dump', help='dump grayscale resized image, L0_result, L1_result of input image',dest='dump', const=True, nargs='?')
    args=parser.parse_args()
    return args
    
### main function
def main():
    #print("Hello")
    # prase inputs in command
    inputs=parse_args()
    # load img
    path = inputs.input_img
    img = Image.open(path)
    (w,h) = img.size
    print(f'input size : w = {w}, h = {h}, {img.format}')
    # convert to gray
    gray_img = img.convert('L')
    # resize to 64*64
    resize_img = gray_img.resize((64, 64))
    (w,h) = resize_img.size
    print(f'resize_img : w = {w}, h = {h}')
    if(inputs.dump):
        print("I dumped!, file name : 64_64_gray_resized.png")
        resize_img.save("64_64_gray_resized.png")
    
    # HW4 fixed DECIMAL
    HW4_kernel_dec =  asarray([[-0.0625, 0, -0.125, 0, -0.0625], [0, 0, 0, 0, 0], [-0.25, 0, 1, 0, -0.25], [0, 0, 0, 0, 0], [-0.0625, 0, -0.125, 0, -0.0625]])
    HW4_bias_dec = -0.75
    
    # output pipeline
    data = asarray(resize_img,  dtype=np.float32) #  dtype=np.uint8
    conv_img = convolution2d(image = data, kernel = HW4_kernel_dec, stride = 1, padding = 2, bias = HW4_bias_dec)  
    relu(conv_img)
    
    if(inputs.dump):
        print("I dumped!, file name : L0_result.png")
        Image.fromarray(conv_img.astype('uint8')).save("L0_result.png")
        
    maxpooled_img = maxpooling2d(image=conv_img, kernelSize=2, stride=2, padding=0)
    
    if(inputs.dump):
        print("I dumped!, file name : L1_result.png")
        Image.fromarray(maxpooled_img.astype('uint8')).save("L1_result.png")
    
    file_save(data)
    file_save(conv_img, file_name = "layer0_golden.dat", mode = "w")
    file_save(maxpooled_img, file_name = "layer1_golden.dat", mode = "w")
    print("Format transform done !! Golden data is ready !!")
    
if __name__ == "__main__":
    main()