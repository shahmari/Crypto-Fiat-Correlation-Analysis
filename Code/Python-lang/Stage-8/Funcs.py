import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import statsmodels.tsa.stattools as sts
from statsmodels.tsa.stattools import grangercausalitytests
from statsmodels.tsa.api import VAR
from statsmodels.tools.eval_measures import rmse, aic
import networkx as nx
import os
import math 
import seaborn as sns

def PrepDataNames(Dir):
    Data_names = os.listdir(Dir)
    symboles = [string_.removesuffix('.csv') for string_ in Data_names]
    markets = []
    cryptos = []
    for sym in symboles:
        sym_ = sym.split('-')
        markets.append(sym_[1])
        cryptos.append(sym_[0])
    return list(set(symboles)), list(set(markets)), list(set(cryptos))

def LoadData(Dir, symboles, markets, cryptos):
    TimeStamp = pd.read_csv(Dir + '/%s.csv' %symboles[0])
    CryptoData = {'Timestamp' : pd.to_datetime(TimeStamp['timestamp'].iloc[1:], dayfirst= True)}
    for market in markets:
        CryptoData['%s' % market] = {}
        for crypto in cryptos:
            Data = pd.read_csv(Dir + "/%s-%s.csv" % (crypto , market))
            CryptoData['%s' % market]['%s' % crypto] = Data.close.pct_change(1).mul(100).iloc[1:]
    return CryptoData

def Eddy_Fuller_test(Dataframe, cryptos):
    for crypto in cryptos:
        result = sts.adfuller(Dataframe['%s' % crypto])
        print('p-value (%s) = %s ' % (crypto , result[1]) )
        

def Optimum_lag(Dataframe, maxlag_):
    var_model = VAR(Dataframe)
    x = var_model.select_order(maxlags=maxlag_)
    # print('lag_order = ' %var_model.k_ar)
    return x.summary()


test = 'ssr_chi2test'
test = 'ssr_ftest'
def grangers_causation_matrix(data, maxlag_, variables, verbose=False):    
    """Check Granger Causality of all possible combinations of the Time series.
    The rows are the response variable, columns are predictors. The values in the table 
    are the P-Values. P-Values lesser than the significance level (0.05), implies 
    the Null Hypothesis that the coefficients of the corresponding past values is 
    zero, that is, the X does not cause Y can be rejected.

    data      : pandas dataframe containing the time series variables
    variables : list containing names of the time series variables.
    """
    df_p = pd.DataFrame(np.zeros((len(variables), len(variables))), columns=variables, index=variables)
    df_f = pd.DataFrame(np.zeros((len(variables), len(variables))), columns=variables, index=variables)
    for c in df_p.columns:
        for r in df_p.index:
            test_result = grangercausalitytests(data[[r, c]], maxlag=maxlag_, verbose=False)
            p_values = [round(test_result[i+1][0]['ssr_chi2test'][1],4) for i in range(maxlag_)]
            F_score = round(test_result[maxlag_][0]['ssr_ftest'][0],4)            
            if verbose: print(f'Y = {r}, X = {c}, P Values = {p_values}')
            min_p_value = np.min(p_values)
            df_p.loc[r, c] = min_p_value
            df_f.loc[r, c] = F_score
    df_f.columns = [var + '_x' for var in variables]
    df_f.index = [var + '_y' for var in variables]      
    df_p.columns = [var + '_x' for var in variables]
    df_p.index = [var + '_y' for var in variables] 
     
    return df_p, df_f


def ScaleData(Dataframe):
    Mat = 1 - np.array(Dataframe)
    #Mat = np.array(Dataframe)
    Mat = (Mat - Mat.min()) / (Mat.max() - Mat.min())
    # for i in range(len(Mat)):
    #     for j in range(len(Mat)):
    #         Mat[i,j] = round(Mat[i,j] , 1)
    # for i in range(len(Mat)):
    #     Mat[i,i] = 0.0
    return Mat

def CalculateDistance(c) : 
    return math.sqrt(2) * (1 - c)

def nudge(pos, x_shift, y_shift):
    return {n:(x + x_shift, y + y_shift) for n,(x,y) in pos.items()}

def MST_Graph(Mat, cryptos):
    sns.set(rc = {"figure.figsize":(4,2)})

    G_ = nx.from_numpy_array(Mat)

    G=nx.minimum_spanning_tree(G_)

    labels={}
    for i in range(len(G.nodes())):
        labels[list(G.nodes)[i]] = cryptos[i]   
    H = nx.relabel_nodes(G, labels)
    pos = nx.spring_layout(H, seed=7, weight='length')
    pos_nodes = nudge(pos, 0.08, 0)  

    weight_labels = nx.get_edge_attributes(H,'weight')
    # elarge = [(u, v) for (u, v, d) in H.edges(data=True) if d["weight"] > 0.5]
    # esmall = [(u, v) for (u, v, d) in H.edges(data=True) if d["weight"] <= 0.5]
    #, edgelist=esmall
    #node_size = [v * 10 for v in d.values()]
    d = dict(H.degree)
    nx.draw_networkx_nodes(H, pos, node_size = 3 , node_color="skyblue")
    nx.draw_networkx_labels(H, pos_nodes, font_size=3, font_family="sans-serif")
    #nx.draw_networkx_edges(H, pos, width=0.5)
    nx.draw_networkx_edges(
        H, pos, width=0.5, alpha=0.5, edge_color="b", style="dashed")

