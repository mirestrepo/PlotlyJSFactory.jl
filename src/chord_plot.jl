using NetworkLayout
using LightGraphs

"""
    chord_parameters()
Returns the control points, thresholds and parameters for generating chord diagram
For now the number of control points is fixed to 5. Could extend in future
"""
function chord_parameters()
    #unit circle control points angles 0,π/4 π/2,3π/4,π
    cpoints = Array{Array{Float64}}(5)
    cpoints[1] = [1, 0]
    cpoints[2] = sqrt(2)/2.* [1, 1]
    cpoints[3] = [0, 1]
    cpoints[4] = sqrt(2)/2.* [-1, 1]
    cpoints[5] = [-1, 0]

    thresh_dist = [dist(cpoints[1], cpoints[i]) for i=1:5]
    params=[1.2, 1.5, 1.8, 2.1];

    return thresh_dist, params
end


# Bezier related code used for chord-diagram:
# Translated from python example plohttps://plot.ly/python/chord-diagram/
function dist(A,B)
    norm(A-B)
end

"""
Returns the index of the interval the distance d belongs to
"""
function get_idx_interv(d, D)
    k=1
    while(d>D[k])
        k+=1
    end
    return  k-1
end
    
"""
Returns the point corresponding to the parameter t, on a Bézier curve of control points given in the list b
"""
function deCasteljau(b,t)
    N=length(b) 
    if(N<2)
        error("The  control polygon must have at least two points")
    end
    a=copy(b) #shallow copy of the list of control points 
    for r=1:N
        a[1:N-r,:]=(1-t)*a[1:N-r,:]+t*a[2:N-r+1,:]
    end
    return a[1,:][1]
end

"""
Returns an array of shape (nr, 2) containing the coordinates of nr points evaluated on the Bézier curve, 
at equally spaced parameters in [0,1].
"""
function BezierCv(b; nr=5)
    t=linspace(0, 1, nr)
    bp = Array{Float64}(nr, 2)
    for k=1:nr
        bp[k,:] = deCasteljau(b, t[k])
    end
    return bp
end

"""
Creatres a chord plot from an affinity matrix
"""
function create_chord_plot(affinity_mat; labels::Vector{String} = Vector{String}() )

    #Build network layout from adjacency matrix (handles co-occurrance)
    #Returns the coordinates of nodes in the layout
    circular_net = NetworkLayout.Circular.layout(affinity_mat);
    G = Graph(affinity_mat - spdiagm(diag(affinity_mat)))

    max_val = maximum(affinity_mat - spdiagm(diag(affinity_mat)))
    
    # colors = distinguishable_colors(length(labels), RGB(1,0,0))
    locs_x = map( (point)->point[1], circular_net )
    locs_y = map( (point)->point[2], circular_net )
    
    traces=Array{PlotlyJS.GenericTrace{Dict{Symbol,Any}},1}()
    
    thresh_dist, params = chord_parameters()
    
    # Bezier curves:
    for e in edges(G)
        A = [ locs_x[e.src], locs_y[e.src]]
        B = [ locs_x[e.dst], locs_y[e.dst]]
        d= dist(A, B)
        K= get_idx_interv(d, thresh_dist)
        b= [A, A/params[K], B/params[K], B]
        pts= BezierCv(b, nr=5)
    #     println(pts)
    #     println("------")
        
        line_trace =scatter(x=pts[:,1],
                         y=pts[:,2],
                         mode="lines",
                         line=attr(shape="spline", color="rgba(0,51,181, 0.85)",
                                   width=5*affinity_mat[e.src, e.dst]./max_val#The  width is proportional to the edge weight
                                  ), 
                        hoverinfo="none"
                       )
        push!(traces, line_trace)
    end
    
    # node_trace = scatter(;x=locs_x, y=locs_y, mode="markers",
    #                 marker=attr(symbol="circle-open", size=mesh_counts[count_perm[2:topn]]/50, color="rgba(0,51,181, 0.85)"),
    #                 hoverinfo="none"
    #                 ) #, mode="text",textposition="top", text=labels, opacity=0.8)
    
    # push!(traces, node_trace)
    
    
    all_an = []
    for pid = 1:length(locs_x)
        annot = attr(x=locs_x[pid],y=locs_y[pid],xref="x", yref="y", text=labels[pid], textangle=-atan(locs_y[pid]./locs_x[pid]).*180/π,
                        showarrow=true,  ax=locs_x[pid]*130, ay=-locs_y[pid]*130, arrowhead = 6)
        push!(all_an, annot)
    end
    
    
    layout = Layout(showlegend=false, width=930, height=1000, showgrid=false,
                    margin= Dict(:t=> 70, :r=> 0, :l=> 0, :b=>0),
                    xaxis=attr(showline=false, zeroline=false, showgrid=false, showticklabels=false),
                    yaxis=attr(showline=false, zeroline=false, showgrid=false, showticklabels=false),
                    annotations = all_an)
    
    plot(traces, layout)
end


