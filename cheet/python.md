---
title: "Python Cheat Sheet"
---

## List Slicing

```python
my_list = [1, 2, 3, 4, 5]

# Slicing examples
print(my_list[1:4])  # Output: [2, 3, 4]
print(my_list[:3])   # Output: [1, 2, 3]
print(my_list[2:])   # Output: [3, 4, 5]
print(my_list[-3:])  # Output: [3, 4, 5]
print(my_list[::2])  # Output: [1, 3, 5]
```

## List Comprehensions

```python
squares = [x**2 for x in range(10)]
print(squares)  # Output: [0, 1, 4, 9, 16, 25, 36, 49, 64, 81]
```
