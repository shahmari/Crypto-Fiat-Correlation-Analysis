import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import statsmodels.tsa.stattools as sts
from statsmodels.tsa.stattools import grangercausalitytests
from statsmodels.tsa.api import VAR
from statsmodels.tools.eval_measures import rmse, aic
import networkit as nk 
import networkx as nx
from igraph import *
import seaborn as sns

def RepairData(Dir, symboles):
    for sym in symboles:
        df = pd.read_csv(Dir + "Stage-4-Data/%s.csv" % sym)
        data = df["time_period_start;time_period_end;time_open;time_close;rate_open;rate_high;rate_low;rate_close"].str.split(";", expand=True)
        data.rename(columns={0: 'time_period_start', 1: 'time_period_end', 2: 'time_open', 3: 'time_close',
            4: 'rate_open', 5: 'rate_high', 6: 'rate_low', 7: 'rate_close'}, inplace=True)
        data.to_csv(Dir + 'Stage-7-Data/%s.csv' % sym , index=False)

def LoadData(Dir, symboles):
    Data_t = pd.read_csv(Dir + "Stage-7-Data/%s.csv" % symboles[1])
    returns_df = pd.DataFrame()
    returns_df['time_close'] = pd.to_datetime(Data_t['time_close'], dayfirst= True)
    for sym in symboles:
        Data = pd.read_csv(Dir + "Stage-7-Data/%s.csv" % sym)
        returns_df['%s' % sym] = Data.rate_close.pct_change(1).mul(100)
    returns_df = returns_df.iloc[1:]
    returns_df.fillna('ffill')
    return returns_df

def Eddy_Fuller_test(Dataframe, symboles):
    for sym in symboles:
        result = sts.adfuller(Dataframe['%s' % sym])
        print('p-value (%s) = %s ' % (sym , result[1]) )


def Optimum_lag(Dataframe, symboles, maxlag_, first_col, end_col):
    var_model = VAR(Dataframe.iloc[:, first_col:end_col])
    x = var_model.select_order(maxlags=maxlag_)
    return x.summary()


maxlag = 4
test = 'ssr_chi2test'
test = 'ssr_ftest'
def grangers_causation_matrix(data, variables, verbose=False):    
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
            test_result = grangercausalitytests(data[[r, c]], maxlag=maxlag, verbose=False)
            p_values = [round(test_result[i+1][0]['ssr_chi2test'][1],4) for i in range(maxlag)]
            F_score = round(test_result[maxlag][0]['ssr_ftest'][0],4)            
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
    for i in range(len(Mat)):
        for j in range(len(Mat)):
            Mat[i,j] = round(Mat[i,j] , 1)
    for i in range(5):
        Mat[i,i] = 0.0
    return Mat


def MST_Graph(Mat, symboles):

    G_ = nx.from_numpy_array(Mat)

    G=nx.minimum_spanning_tree(G_)
    edge_labels = nx.get_edge_attributes(G, "weight")
    elarge = [(u, v) for (u, v, d) in G.edges(data=True) if d["weight"] > 0.5]
    esmall = [(u, v) for (u, v, d) in G.edges(data=True) if d["weight"] <= 0.5]

    pos = nx.spring_layout(G, seed=7)
    nx.draw_networkx_labels(G, pos, font_size=10, font_family="sans-serif")

    labels={}
    for i in range(len(G.nodes())):
        labels[list(G.nodes)[i]] = symboles[i]

    nx.draw_networkx_nodes(G, pos, labels, node_size=50)
    nx.draw_networkx_edges(G, pos, edgelist=elarge, width=1)
    nx.draw_networkx_edges(
        G, pos, edgelist=esmall, width=2, alpha=0.5, edge_color="b", style="dashed")
