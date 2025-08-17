package com.copydrop.android.adapter

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.TextView
import com.copydrop.android.R
import com.copydrop.android.model.ClipboardHistory

class ClipboardHistoryAdapter(
    private val context: Context,
    private val historyList: MutableList<ClipboardHistory>
) : BaseAdapter() {
    
    private val inflater = LayoutInflater.from(context)
    
    override fun getCount(): Int = historyList.size
    
    override fun getItem(position: Int): ClipboardHistory = historyList[position]
    
    override fun getItemId(position: Int): Long = position.toLong()
    
    override fun getView(position: Int, convertView: View?, parent: ViewGroup?): View {
        val view = convertView ?: inflater.inflate(R.layout.item_clipboard_history, parent, false)
        
        val history = getItem(position)
        
        val contentText = view.findViewById<TextView>(R.id.contentText)
        val timeText = view.findViewById<TextView>(R.id.timeText)
        val directionText = view.findViewById<TextView>(R.id.directionText)
        
        contentText.text = history.getPreviewText()
        timeText.text = history.getFormattedTime()
        
        // 통합된 방향 표시 개선
        when (history.direction) {
            ClipboardHistory.Direction.SENT -> {
                directionText.text = "📤 → ${history.deviceName}"
                directionText.setTextColor(context.resources.getColor(android.R.color.holo_blue_dark))
                view.setBackgroundColor(context.resources.getColor(android.R.color.background_light))
            }
            ClipboardHistory.Direction.RECEIVED -> {
                directionText.text = "📥 ← ${history.deviceName}"
                directionText.setTextColor(context.resources.getColor(android.R.color.holo_green_dark))
                view.setBackgroundColor(context.resources.getColor(android.R.color.background_light))
            }
        }
        
        return view
    }
    
    fun addHistory(history: ClipboardHistory) {
        // 중복 방지: 같은 내용과 방향의 최근 항목이 있으면 무시
        if (historyList.isNotEmpty()) {
            val lastHistory = historyList.first()
            if (lastHistory.content == history.content && 
                lastHistory.direction == history.direction &&
                System.currentTimeMillis() - lastHistory.timestamp < 2000) { // 2초 내 중복
                android.util.Log.d("ClipboardHistoryAdapter", "⚠️ 중복 기록 무시: ${history.content.take(30)}...")
                return
            }
        }
        
        // 맨 위에 새 항목 추가
        historyList.add(0, history)
        
        // 최대 50개까지만 유지
        if (historyList.size > 50) {
            historyList.removeAt(historyList.size - 1)
        }
        
        notifyDataSetChanged()
        android.util.Log.d("ClipboardHistoryAdapter", "✅ 새 기록 추가: ${history.getDirectionText()} ${history.content.take(30)}...")
    }
    
    fun clearHistory() {
        historyList.clear()
        notifyDataSetChanged()
    }
}