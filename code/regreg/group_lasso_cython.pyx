import numpy as np, sys
cimport numpy as np

"""
Implements prox and dual of group LASSO, strong set, seminorm and dual seminorm.
"""

DTYPE_float = np.float
ctypedef np.float_t DTYPE_float_t
DTYPE_int = np.int
ctypedef np.int_t DTYPE_int_t

#TODO: Add some documentation to this!

def prox_group_lasso(np.ndarray[DTYPE_float_t, ndim=1] prox_center, 
                     DTYPE_float_t lagrange, DTYPE_float_t lipschitz,
                     np.ndarray[DTYPE_int_t, ndim=1] l1_penalty, 
                     np.ndarray[DTYPE_int_t, ndim=1] unpenalized,
                     np.ndarray[DTYPE_int_t, ndim=1] positive_part, 
                     np.ndarray[DTYPE_int_t, ndim=1] groups,
                     np.ndarray[DTYPE_float_t, ndim=1] weights):
    
    cdef np.ndarray norms = np.zeros_like(weights)
    cdef np.ndarray projection = np.zeros_like(prox_center)
    cdef int i, j
    cdef int p = groups.shape[0]
    
    cdef lf = lagrange / lipschitz
    
    for i in range(p):
        if groups[i] >= 0:
            norms[groups[i]] = norms[groups[i]] + prox_center[i]**2
    
    for j in range(weights.shape[0]):
        norms[j] = np.sqrt(norms[j])
        projection[groups == j] = prox_center[groups == j] / norms[j] * min(norms[j], lf * weights[j])
    
    projection[l1_penalty] = prox_center[l1_penalty] * np.minimum(1, lf / np.fabs(prox_center[l1_penalty]))
    projection[unpenalized] = 0
    projection[positive_part] = np.minimum(lf, prox_center[positive_part])
    
    return prox_center - projection

def project_group_lasso(np.ndarray[DTYPE_float_t, ndim=1] prox_center, 
                     DTYPE_float_t bound, 
                     np.ndarray[DTYPE_int_t, ndim=1] l1_penalty, 
                     np.ndarray[DTYPE_int_t, ndim=1] unpenalized,
                     np.ndarray[DTYPE_int_t, ndim=1] positive_part, 
                     np.ndarray[DTYPE_int_t, ndim=1] groups,
                     np.ndarray[DTYPE_float_t, ndim=1] weights):
    
    cdef np.ndarray norms = np.zeros_like(weights)
    cdef np.ndarray projection = np.zeros_like(prox_center)
    cdef int i, j
    cdef int p = groups.shape[0]
    
    for i in range(p):
        if groups[i] >= 0:
            norms[groups[i]] = norms[groups[i]] + prox_center[i]**2
    
    for j in range(weights.shape[0]):
        norms[j] = np.sqrt(norms[j])
        projection[groups == j] = prox_center[groups == j] / norms[j] * min(norms[j], bound * weights[j])
    
    projection[l1_penalty] = prox_center[l1_penalty] * np.minimum(1, bound / np.fabs(prox_center[l1_penalty]))
    projection[unpenalized] = 0
    projection[positive_part] = np.minimum(bound, prox_center[positive_part])
    
    return projection

def seminorm_group_lasso(np.ndarray[DTYPE_float_t, ndim=1] x, 
                         np.ndarray[DTYPE_int_t, ndim=1] l1_penalty, 
                         np.ndarray[DTYPE_int_t, ndim=1] unpenalized,
                         np.ndarray[DTYPE_int_t, ndim=1] positive_part, 
                         np.ndarray[DTYPE_int_t, ndim=1] groups,
                         np.ndarray[DTYPE_float_t, ndim=1] weights,
                         DTYPE_int_t check_feasibility):
    
    cdef np.ndarray norms = np.zeros_like(weights)
    cdef int i, j
    cdef DTYPE_float_t value
    cdef int p = groups.shape[0]
    
    for i in range(p):
        if groups[i] >= 0:
            norms[groups[i]] = norms[groups[i]] + x[i]**2
    
    value = np.fabs(x[l1_penalty]).sum()
    value += np.maximum(x[positive_part], 0).sum()

    for j in range(weights.shape[0]):
        norms[j] = np.sqrt(norms[j])
        value += weights[j] * norms[j]

    tol = 1.e-5
    if check_feasibility:
        xpos = x[positive_part]
        if tuple(xpos.shape) not in [(),(0,)] and xpos.min() < tol:
            value = np.inf
    return value


def strong_set_group_lasso(np.ndarray[DTYPE_float_t, ndim=1] x, 
                           DTYPE_float_t lagrange_new,
                           DTYPE_float_t lagrange_cur,
                           DTYPE_float_t slope_estimate,
                           np.ndarray[DTYPE_int_t, ndim=1] l1_penalty, 
                           np.ndarray[DTYPE_int_t, ndim=1] unpenalized,
                           np.ndarray[DTYPE_int_t, ndim=1] positive_part, 
                           np.ndarray[DTYPE_int_t, ndim=1] groups,
                           np.ndarray[DTYPE_float_t, ndim=1] weights):
    
    cdef np.ndarray value = np.zeros_like(x)
    cdef np.ndarray norms = np.zeros_like(weights)
    cdef int i, j
    cdef int p = groups.shape[0]
    
    for i in range(p):
        if groups[i] >= 0:
            norms[groups[i]] = norms[groups[i]] + x[i]**2
    
    value[l1_penalty] = np.fabs(x[l1_penalty]) < (slope_estimate+1)*lagrange_new - slope_estimate*lagrange_cur
    value[positive_part] = -x[positive_part] < (slope_estimate+1) * lagrange_new - slope_estimate*lagrange_cur

    for j in range(weights.shape[0]):
        norms[j] = np.sqrt(norms[j])
        value[groups == j] = norms[j] < weights[j] * (slope_estimate+1) * lagrange_new - slope_estimate*lagrange_cur

    return 1 - value

def check_KKT_group_lasso(np.ndarray[DTYPE_float_t, ndim=1] grad, 
                          np.ndarray[DTYPE_float_t, ndim=1] solution, 
                          DTYPE_float_t lagrange,
                          np.ndarray[DTYPE_int_t, ndim=1] l1_penalty, 
                          np.ndarray[DTYPE_int_t, ndim=1] unpenalized,
                          np.ndarray[DTYPE_int_t, ndim=1] positive_part, 
                          np.ndarray[DTYPE_int_t, ndim=1] groups,
                          np.ndarray[DTYPE_float_t, ndim=1] weights,
			  DTYPE_float_t tol=1.e-2):
    
    cdef np.ndarray failing = np.zeros_like(grad)
    cdef np.ndarray norms = np.zeros_like(weights)
    cdef np.ndarray snorms = np.zeros_like(weights)
    cdef int i, j
    cdef int p = groups.shape[0]
    
    # L1 check

    cdef int debug = 0
    g_l1 = grad[l1_penalty]
    if g_l1.shape not in [(), (0,)]:

        failing[l1_penalty] += np.fabs(g_l1) > lagrange * (1 + tol)
        if debug:
            print 'l1 (dual) feasibility:', np.fabs(g_l1) > lagrange * (1 + tol), np.fabs(g_l1), lagrange * (1 + tol)

        # Check that active coefficients are on the boundary 
        soln_l1 = solution[l1_penalty]
        active_l1 = soln_l1 != 0

        failing_l1 = np.zeros(g_l1.shape, np.int)
        failing_l1[active_l1] = np.fabs(-g_l1[active_l1] / lagrange - np.sign(soln_l1[active_l1])) >= tol 
        failing[l1_penalty] += failing_l1

        if debug:
            print 'l1 (dual) tightness:', failing_l1, np.fabs(-g_l1[active_l1] / lagrange - np.sign(soln_l1[active_l1]))

    # Positive part

    # Check subgradient is feasible
            
    g_pp = grad[positive_part]
    if g_pp.shape not in [(), (0,)]:
        failing[positive_part] += -g_pp > lagrange * (1 + tol)
        if debug:
            print 'positive part (dual) feasibility:', -g_pp > lagrange * (1 + tol)

        # Check that active coefficients are on the boundary 
        soln_pp = solution[positive_part]
        active_pp = soln_pp != 0

        failing_pp = np.zeros(g_pp.shape, np.int)
        failing_pp[active_pp] += np.fabs(-g_pp[active_pp] / lagrange - 1) >= tol 
        if debug:
            print 'positive part (dual) tightness:', -g_pp[active_pp] / lagrange - 1
        failing[positive_part] += failing_pp

    # group norms

    for i in range(p):
        if groups[i] >= 0:
            norms[groups[i]] = norms[groups[i]] + grad[i]**2
            snorms[groups[i]] = snorms[groups[i]] + solution[i]**2

    for j in range(weights.shape[0]):
        norms[j] = np.sqrt(norms[j])

        # check that the subgradient is feasible 

        failing[groups == j] = norms[j] > weights[j] * lagrange * (1 + tol)

        # check that the active groups have a tight subgradient
        
        if snorms[j] != 0:
            failing[groups == j] += norms[j] < weights[j] * lagrange * (1 - tol)

    return failing

   
def seminorm_group_lasso_conjugate(np.ndarray[DTYPE_float_t, ndim=1] x, 
                                   np.ndarray[DTYPE_int_t, ndim=1] l1_penalty, 
                                   np.ndarray[DTYPE_int_t, ndim=1] unpenalized,
                                   np.ndarray[DTYPE_int_t, ndim=1] positive_part, 
                                   np.ndarray[DTYPE_int_t, ndim=1] groups,
                                   np.ndarray[DTYPE_float_t, ndim=1] weights):
    
    cdef np.ndarray norms = np.zeros_like(weights)
    cdef int i
    cdef DTYPE_float_t value
    cdef int p = groups.shape[0]
    
    for i in range(p):
        if groups[i] >= 0:
            norms[groups[i]] = norms[groups[i]] + x[i]**2
    
    xl1 = x[l1_penalty]
    if xl1.shape not in [(), (0,)]:
        value = np.fabs(xl1).max()
    else:
        value = -np.inf

    xpos = x[positive_part]
    if xpos.shape not in [(), (0,)]:
        value = max(value, np.maximum(xpos, 0).max())

    for j in range(weights.shape[0]):
        norms[j] = np.sqrt(norms[j])
        value = max(value, weights[j] * norms[j])

    return value

